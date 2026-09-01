module shift_reg
#(
parameter SPI_DATA_WIDTH = 8
)
(
input                           pclk,
input                           preset_n,
input                           ss_i,
input                           send_data_i,
input                           lsbfe_i,
input                           cpha_i,
input                           cpol_i,
input                           miso_receive_sclk_i,
input                           miso_receive_sclk0_i,
input                           mosi_send_sclk_i,
input                           mosi_send_sclk0_i,
input      [SPI_DATA_WIDTH-1:0] data_mosi_i,
input                           miso_i,
input                           receive_data_i,
output reg                      mosi_o,
output reg [SPI_DATA_WIDTH-1:0] data_miso_o
);


reg [SPI_DATA_WIDTH-1:0] shift_register;
reg [SPI_DATA_WIDTH-1:0] temp_reg;


reg [$clog2(SPI_DATA_WIDTH)-1:0] count_0;
reg [$clog2(SPI_DATA_WIDTH)-1:0] count_1;

reg [$clog2(SPI_DATA_WIDTH)-1:0] count_2;
reg [$clog2(SPI_DATA_WIDTH)-1:0] count_3;

// FIX: Register previous ss_i to detect falling edge
reg ss_d;
always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
      ss_d <= 1'b1;
   else
      ss_d <= ss_i;
end

wire ss_falling = ss_d && !ss_i;


// shift register PARALLEL IN
always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
   begin
      shift_register <= {SPI_DATA_WIDTH{1'b0}};
   end
   else
   begin
      if(send_data_i)
      begin
         shift_register <= data_mosi_i;
      end
      else
      begin
         shift_register <= shift_register;
      end
   end
end

// FIX: master out slave in — REGISTERED output with correct CPHA handling.
// For CPHA=0: load first bit at SS fall, then advance counter so the first
//             send strobe drives the NEXT bit (not the same bit again).
// For CPHA=1: do NOT load at SS fall; the first send strobe drives the
//             first bit, matching SPI spec where data changes on 1st edge.
always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
   begin
      mosi_o <= 1'b0;
   end
   else if(ss_i)
   begin
      mosi_o <= 1'b0;
   end
   else if(ss_falling && !cpha_i)
   begin
      // CPHA=0: load first bit before first SCLK edge
      if(lsbfe_i)
         mosi_o <= shift_register[count_0];
      else
         mosi_o <= shift_register[count_1];
   end
   else if(lsbfe_i && (mosi_send_sclk_i || mosi_send_sclk0_i))
   begin
      mosi_o <= shift_register[count_0];
   end
   else if(!lsbfe_i && (mosi_send_sclk_i || mosi_send_sclk0_i))
   begin
      mosi_o <= shift_register[count_1];
   end
end


// DATA MISO PARALLEL OUT
always @(*)
begin
   if(receive_data_i)
   begin
      data_miso_o = temp_reg;
   end
   else
   begin
      data_miso_o = {SPI_DATA_WIDTH{1'b0}};
   end
end

// COUNTERS FOR SHIFT REGISTER (PISO) - MOSI bit-index counters
// FIX: advance counter on ss_falling for CPHA=0 so the first send strobe
//      does not re-drive the same initial bit.
always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
   begin
      count_0 <= {$clog2(SPI_DATA_WIDTH){1'b0}};
      count_1 <= SPI_DATA_WIDTH - 1;
   end
   else
   begin
      if(ss_i)
      begin
         count_0 <= {$clog2(SPI_DATA_WIDTH){1'b0}};
         count_1 <= SPI_DATA_WIDTH - 1;
      end
      else if(ss_falling && !cpha_i)
      begin
         // CPHA=0: counter advanced after initial load
         if(lsbfe_i)
            count_0 <= count_0 + 1'b1;
         else
            count_1 <= count_1 - 1'b1;
      end
      else if(!ss_i && (lsbfe_i) && (mosi_send_sclk_i))
      begin
         count_0 <= count_0 + 1'b1;
      end
      else if(!ss_i && (!lsbfe_i) && (mosi_send_sclk_i))
      begin
         count_1 <= count_1 - 1'b1;
      end
      else if(!ss_i && (lsbfe_i) && (mosi_send_sclk0_i))
      begin
         count_0 <= count_0 + 1'b1;
      end
      else if(!ss_i && (!lsbfe_i) && (mosi_send_sclk0_i))
      begin
         count_1 <= count_1 - 1'b1;
      end
      else
      begin
         count_0 <= count_0;
         count_1 <= count_1;
      end
   end
end

// COUNTERS FOR SHIFT REGISTER (PISO) - MISO bit-index counters
always @(posedge pclk or negedge preset_n)
begin
   if(preset_n == 1'b0)
   begin
      count_2  <= {$clog2(SPI_DATA_WIDTH){1'b0}};
      count_3  <= SPI_DATA_WIDTH - 1;
      temp_reg <= {SPI_DATA_WIDTH{1'b0}};
   end
   else
   begin
      if(ss_i)
      begin
         count_2  <= {$clog2(SPI_DATA_WIDTH){1'b0}};
         count_3  <= SPI_DATA_WIDTH - 1;
         temp_reg <= temp_reg;
      end
      else if(!ss_i && (lsbfe_i) && (miso_receive_sclk_i))
      begin
         count_2           <= count_2 + 1'b1;
         temp_reg[count_2] <= miso_i;
      end
      else if(!ss_i && (!lsbfe_i) && (miso_receive_sclk_i))
      begin
         count_3           <= count_3 - 1'b1;
         temp_reg[count_3] <= miso_i;
      end
      else if(!ss_i && (lsbfe_i) && (miso_receive_sclk0_i))
      begin
         count_2           <= count_2 + 1'b1;
         temp_reg[count_2] <= miso_i;
      end
      else if(!ss_i && (!lsbfe_i) && (miso_receive_sclk0_i))
      begin
         count_3           <= count_3 - 1'b1;
         temp_reg[count_3] <= miso_i;
      end
      else
      begin
         count_2  <= count_2;
         count_3  <= count_3;
         temp_reg <= temp_reg;
      end
   end
end

endmodule
