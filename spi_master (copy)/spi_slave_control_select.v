`include "spi_register.v"

module spi_slave_control_select
(
input               pclk,
input               preset_n,

input      [1:0]    spi_mode_i,
input               mstr_i,
input               spiswai_i,
input               send_data_i,
input      [11:0]   baud_rate_divisor_i,

output reg          ss_o,
output reg          receive_data_o,
output reg          tip_o          // FIX: changed from wire to reg, registered
);

localparam SPI_RUN  = 2'b00;
localparam SPI_WAIT = 2'b01;
localparam SPI_STOP = 2'b10;

reg  [15:0] count_s;
wire [15:0] target_s;
reg         rcv_s;

assign target_s = baud_rate_divisor_i * 8;

// FIX: tip_o is now a flip-flop so it rises one cycle AFTER ss_o falls.
// This prevents the APB data-register write that starts the transfer
// from seeing tip_i=1 in the same cycle.
always @(posedge pclk or negedge preset_n)
begin
   if (!preset_n)
      tip_o <= 1'b0;
   else
      tip_o <= ~ss_o;
end

always @(posedge pclk or negedge preset_n)
begin
   if (!preset_n)
   begin
      count_s <= {16{1'b1}};
      ss_o    <= 1'b1;
      rcv_s   <= 1'b0;
   end
   else if (mstr_i && ((spi_mode_i == SPI_RUN) ||
                        ((spi_mode_i == SPI_WAIT) && (!spiswai_i))))
   begin
      if (send_data_i)
      begin
         ss_o    <= 1'b0;
         count_s <= 16'd0;
         rcv_s   <= 1'b0;
      end
      else if (count_s < (target_s - 1'b1))
      begin
         ss_o    <= 1'b0;
         count_s <= count_s + 1'b1;
         rcv_s   <= 1'b0;
      end
      else if (count_s == (target_s - 1'b1))
      begin
         ss_o    <= 1'b0;
         rcv_s   <= 1'b1;
         count_s <= count_s + 1'b1;
      end
      else
      begin
         ss_o    <= 1'b1;
         rcv_s   <= 1'b0;
         count_s <= {16{1'b1}};
      end
   end
   else
   begin
      ss_o    <= 1'b1;
      rcv_s   <= 1'b0;
      count_s <= {16{1'b1}};
   end
end

always @(posedge pclk or negedge preset_n)
begin
   if (!preset_n)
      receive_data_o <= 1'b0;
   else
      receive_data_o <= rcv_s;
end

endmodule
