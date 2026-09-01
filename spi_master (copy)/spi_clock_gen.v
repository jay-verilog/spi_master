`include "spi_register.v"

module spi_clock_gen
#(
parameter SPI_MODES = 3,
parameter BAUD_DIVISOR = 12, 
parameter BAUD_PRE_SEL_BITS_WIDTH = 3,
parameter BAUD_SEL_BITS_WIDTH = 3
)
(
input                                    pclk,
input                                    preset_n,

input      [$clog2(SPI_MODES)-1:0]       spi_mode_i,

input                                    ss_i,
input                                    spiswai_i,

input      [BAUD_PRE_SEL_BITS_WIDTH-1:0] sppr_i,
input      [BAUD_SEL_BITS_WIDTH-1:0]     spr_i,

input                                    cpol_i,
input                                    cpha_i,

output reg                               sclk_o,

output reg                               miso_receive_sclk_o,
output reg                               miso_receive_sclk0_o,
output reg                               miso_send_sclk_o,
output reg                               miso_send_sclk0_o,
output     [BAUD_DIVISOR-1:0]            baud_rate_divisor_o
);



localparam SPI_RUN  = 2'b00;
localparam SPI_WAIT = 2'b01;
localparam SPI_STOP = 2'b10;

reg [BAUD_DIVISOR-1:0]  count;
reg pre_sclk;

always @(*)
begin
   pre_sclk = cpol_i;
end

assign baud_rate_divisor_o = ((sppr_i + 1'b1) * (2 ** (spr_i + 1'b1)));

wire [BAUD_DIVISOR-1:0] half_period_cnt;
wire [BAUD_DIVISOR-1:0] send_cnt;

assign half_period_cnt = (baud_rate_divisor_o - 1'b1) >> 1;


assign send_cnt = (half_period_cnt == {BAUD_DIVISOR{1'b0}}) ? half_period_cnt : (half_period_cnt - 1'b1);

always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
   begin
      count  <= {BAUD_DIVISOR{1'b0}};
      sclk_o <= pre_sclk; 
   end

   else
   begin
      if((!ss_i) && (!spiswai_i) && ((spi_mode_i == SPI_RUN) || (spi_mode_i == SPI_WAIT)) && (count == half_period_cnt))
      begin
         sclk_o <= (~sclk_o);
         count  <= {BAUD_DIVISOR{1'b0}};  
      end
      else if((!ss_i) && (!spiswai_i) && ((spi_mode_i == SPI_RUN) || (spi_mode_i == SPI_WAIT)) && (count != half_period_cnt))
      begin
         sclk_o <= sclk_o;
         count  <= count + 1'b1;
      end

      else  
      begin
         sclk_o <= pre_sclk;
         count  <= {BAUD_DIVISOR{1'b0}};
      end
   end
end


always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
   begin
      miso_receive_sclk_o  <= 1'b0;
      miso_receive_sclk0_o <= 1'b0;
   end

   else
   begin
      if((sclk_o && (((!cpha_i) && cpol_i) || (cpha_i && (!cpol_i)))) && (count == half_period_cnt))
      begin 
         miso_receive_sclk_o  <= 1'b1;
         miso_receive_sclk0_o <= 1'b0;
      end

      else if(((!sclk_o) && (!(((!cpha_i) && cpol_i) || (cpha_i && (!cpol_i))))) && (count == half_period_cnt)) 
      begin 
            miso_receive_sclk_o  <= 1'b0;
            miso_receive_sclk0_o <= 1'b1;
      end

      else
      begin 
         miso_receive_sclk_o  <= 1'b0;
         miso_receive_sclk0_o <= 1'b0;
      end
   end
end

// FIX: Swap phase conditions for send strobes.
// The original code used the SAME phase condition for both receive and send,
// causing send and receive to fire on the same SCLK edge. In SPI, the master
// should drive (send) on the opposite edge from where the slave samples
// (receive). By negating the phase condition for send, the strobes are
// correctly placed on opposite edges for all four modes.
//
// Mode 0 (CPOL=0,CPHA=0): receive on rising, send on falling  <- was both rising
// Mode 1 (CPOL=0,CPHA=1): receive on falling, send on rising  <- was both falling
// Mode 2 (CPOL=1,CPHA=0): receive on falling, send on rising  <- was both falling
// Mode 3 (CPOL=1,CPHA=1): receive on rising, send on falling  <- was both rising
always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
   begin
      miso_send_sclk_o  <= 1'b0;
      miso_send_sclk0_o <= 1'b0;
   end

   else
   begin
      if((sclk_o && (!(((!cpha_i) && cpol_i) || (cpha_i && (!cpol_i))))) && (count == send_cnt))
      begin 
         miso_send_sclk_o  <= 1'b1;
         miso_send_sclk0_o <= 1'b0;
      end

      else if(((!sclk_o) && (((!cpha_i) && cpol_i) || (cpha_i && (!cpol_i)))) && (count == send_cnt)) 
      begin 
         miso_send_sclk_o  <= 1'b0;
         miso_send_sclk0_o <= 1'b1;
      end

      else
      begin 
         miso_send_sclk_o  <= 1'b0;
         miso_send_sclk0_o <= 1'b0;
      end
   end
end


endmodule
