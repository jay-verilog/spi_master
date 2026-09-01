`include "spi_register.v"

module apb_slave_interface
#(
parameter APB_ADDR_WIDTH = 3,
parameter APB_DATA_WIDTH = 8,
parameter REG_WIDTH      = 8,
parameter SPI_DATA_WIDTH = 8,
parameter SPI_MODES      = 3,
parameter BAUD_RATE_PRESEL_BIT_WIDTH = 3,
parameter BAUD_RATE_SEL_BIT_WIDTH    = 3
)
(
input                                       pclk,
input                                       preset_n,

input      [APB_ADDR_WIDTH-1:0]             paddr_i,
input                                       pwrite_i,
input                                       psel_i,
input                                       penable_i,
input      [APB_DATA_WIDTH-1:0]             pwdata_i,

input                                       ss_i,
input      [SPI_DATA_WIDTH-1:0]             miso_data_i,
input                                       receive_data_i,
input                                       tip_i,

output reg [APB_DATA_WIDTH-1:0]             prdata_o,
output reg                                  pready_o,
output reg                                  pslverr_o,

output reg                                  mstr_o,
output reg                                  cpol_o,
output reg                                  cpha_o,
output reg                                  lsbfe_o,
output reg                                  spiswai_o,
output reg [BAUD_RATE_PRESEL_BIT_WIDTH-1:0] sppr_o,
output reg [BAUD_RATE_SEL_BIT_WIDTH-1:0]    spr_o,
output reg                                  spi_interrupt_request_o,
output reg                                  send_data_o,
output reg [APB_DATA_WIDTH-1:0]             mosi_data_o,
output reg [$clog2(SPI_MODES)-1:0]          spi_mode_o
);

localparam SPI_NUM_STATES = 3;
localparam APB_NUM_STATES = 3;

localparam SPI_RUN  = 2'b00;
localparam SPI_WAIT = 2'b01;
localparam SPI_STOP = 2'b10;

localparam APB_IDLE   = 2'b00;
localparam APB_SETUP  = 2'b01;
localparam APB_ENABLE = 2'b10;

localparam CR2_MASK = 8'b0001_1011;
localparam BR_MASK  = 8'b0111_0111;

reg [$clog2(SPI_NUM_STATES)-1:0] spi_next_state;
reg [$clog2(SPI_NUM_STATES)-1:0] spi_present_state;
reg [$clog2(APB_NUM_STATES)-1:0] apb_present_state;
reg [$clog2(APB_NUM_STATES)-1:0] apb_next_state;

reg [REG_WIDTH-1:0] src1_reg;
reg [REG_WIDTH-1:0] src2_reg;
reg [REG_WIDTH-1:0] sbrr_reg;
reg [REG_WIDTH-1:0] ssr_reg;
reg [REG_WIDTH-1:0] sdr_reg;

reg spe;
reg spie;
reg sptie;
reg modfen;
reg ssoe;

reg spif;
reg sptef;
reg modf;

reg tx_buffer_full;
reg rx_buffer_full;

wire rd_enb;
wire wr_enb;

assign wr_enb = psel_i && penable_i && pwrite_i;
assign rd_enb = psel_i && penable_i && !pwrite_i;

wire addr_valid;
assign addr_valid = (paddr_i == `SPI_CONTROL_REGISTER1) ||
                    (paddr_i == `SPI_CONTROL_REGISTER2) ||
                    (paddr_i == `SPI_BAUD_RATE_REGISTER) ||
                    (paddr_i == `SPI_STATUS_REGISTER) ||
                    (paddr_i == `SPI_DATA_REGISTER);

always @(*) 
begin
   if((apb_present_state == APB_ENABLE) && (paddr_i == `SPI_DATA_REGISTER))
      pslverr_o = tip_i;
   else if (apb_present_state == APB_ENABLE)
      pslverr_o = ~addr_valid;
   else
      pslverr_o = 1'b0;
end

always @(*) 
begin
   if (apb_present_state == APB_ENABLE)
      pready_o = 1'b1;
   else
      pready_o = 1'b0;
end

always @(*) 
begin
   modf = (!ss_i) && mstr_o && modfen && (!ssoe);
end

always @(*) 
begin
   sptef = !tx_buffer_full;
   spif  = rx_buffer_full;
end

always @(posedge pclk or negedge preset_n) 
begin
   if (preset_n == 1'b0) 
      ssr_reg <= `SPI_STATUS_REGISTER_RST;
   else 
   begin
      ssr_reg[`SPIF]  <= spif;
      ssr_reg[`SPTEF] <= sptef;
      ssr_reg[`MODF]  <= modf;
   end
end

always @(posedge pclk or negedge preset_n) 
begin
   if (preset_n == 1'b0) 
   begin
      src1_reg <= `SPI_CONTROL_REGISTER1_RST;
      src2_reg <= `SPI_CONTROL_REGISTER2_RST;
      sbrr_reg <= `SPI_BAUD_RATE_REGISTER_RST;
   end
   else 
   begin
      if (wr_enb && (paddr_i == `SPI_CONTROL_REGISTER1)) 
         src1_reg <= pwdata_i;
      else if (wr_enb && (paddr_i == `SPI_CONTROL_REGISTER2)) 
         src2_reg <= pwdata_i & CR2_MASK;
      else if (wr_enb && (paddr_i == `SPI_BAUD_RATE_REGISTER)) 
         sbrr_reg <= pwdata_i & BR_MASK;
   end
end

always @(posedge pclk or negedge preset_n) begin
   if (preset_n == 1'b0) 
   begin
      sdr_reg        <= `SPI_DATA_REGISTER_RST;
      tx_buffer_full <= 1'b0;
      rx_buffer_full <= 1'b0;
   end 
   else 
   begin
      if (wr_enb && (paddr_i == `SPI_DATA_REGISTER) && !tip_i) 
      begin
         sdr_reg        <= pwdata_i;
         tx_buffer_full <= 1'b1;
         rx_buffer_full <= 1'b0;
      end 
      else if (receive_data_i) 
      begin
         sdr_reg        <= miso_data_i;
         rx_buffer_full <= 1'b1;
         tx_buffer_full <= 1'b0;
      end 
      else if (rd_enb && (paddr_i == `SPI_DATA_REGISTER)) 
      begin
         rx_buffer_full <= 1'b0;
      end
   end
end

always @(*) begin
   if (rd_enb && (paddr_i == `SPI_CONTROL_REGISTER1))
      prdata_o = src1_reg;
   else if (rd_enb && (paddr_i == `SPI_CONTROL_REGISTER2))
      prdata_o = src2_reg;
   else if (rd_enb && (paddr_i == `SPI_BAUD_RATE_REGISTER))
      prdata_o = sbrr_reg;
   else if (rd_enb && (paddr_i == `SPI_STATUS_REGISTER))
      prdata_o = ssr_reg;
   else if (rd_enb && (paddr_i == `SPI_DATA_REGISTER))
      prdata_o = sdr_reg;
   else
      prdata_o = {REG_WIDTH{1'b0}};
end

always @(*) 
begin
   if (spie && (spif || modf))
       spi_interrupt_request_o = 1'b1;
   else if (sptie && sptef)
       spi_interrupt_request_o = 1'b1;
   else
      spi_interrupt_request_o = 1'b0;
end


always @(posedge pclk or negedge preset_n) 
begin
   if (preset_n == 1'b0) 
      send_data_o <= 1'b0;
   else 
      send_data_o <= wr_enb && (paddr_i == `SPI_DATA_REGISTER) && !tip_i;
end

always @(posedge pclk or negedge preset_n) 
begin
   if (preset_n == 1'b0) 
      mosi_data_o <= {REG_WIDTH{1'b0}};
   else
   begin
      if (wr_enb && (paddr_i == `SPI_DATA_REGISTER) && !tip_i) 
         mosi_data_o <= pwdata_i;
   end
end

always @(posedge pclk or negedge preset_n) 
begin
   if (preset_n == 1'b0)
      apb_present_state <= APB_IDLE;
   else
      apb_present_state <= apb_next_state;
end

always @(*) 
begin
   if (apb_present_state == APB_IDLE) 
   begin
      if (!psel_i)
         apb_next_state = APB_IDLE;
      else
         apb_next_state = APB_SETUP;
   end
   else if (apb_present_state == APB_SETUP) 
   begin
      if (psel_i && !penable_i)
         apb_next_state = APB_SETUP;
      else if (psel_i && penable_i)
         apb_next_state = APB_ENABLE;
      else
         apb_next_state = APB_IDLE;
   end
   else if (apb_present_state == APB_ENABLE) 
   begin
      if (psel_i && penable_i)
         apb_next_state = APB_ENABLE;
      else if (psel_i && !penable_i)
         apb_next_state = APB_SETUP;
      else
         apb_next_state = APB_IDLE;
   end
   else 
      apb_next_state = APB_IDLE;
end

always @(posedge pclk or negedge preset_n) 
begin
   if (preset_n == 1'b0)
      spi_present_state <= SPI_WAIT;
   else
      spi_present_state <= spi_next_state;
end

always @(*) 
begin
   if (spi_present_state == SPI_RUN) 
   begin
      if (!spe)
          spi_next_state = SPI_WAIT;
      else
          spi_next_state = SPI_RUN;
   end
   else if (spi_present_state == SPI_WAIT) 
   begin
      if (!spe)
         spi_next_state = SPI_WAIT;
      else if (spiswai_o)
         spi_next_state = SPI_STOP;
      else if (spe)
         spi_next_state = SPI_RUN;
      else
         spi_next_state = SPI_WAIT;
   end
   else if (spi_present_state == SPI_STOP) 
   begin
      if (spe)
         spi_next_state = SPI_RUN;
      else if (!spiswai_o)
         spi_next_state = SPI_WAIT;
      else
         spi_next_state = SPI_STOP;
   end
   else 
      spi_next_state = SPI_WAIT;
end

always @(*) 
begin
   mstr_o  = src1_reg[`MSTR];
   cpol_o  = src1_reg[`CPOL];
   cpha_o  = src1_reg[`CPHA];
   lsbfe_o = src1_reg[`LSBFE];
   spe     = src1_reg[`SPE];
   spie    = src1_reg[`SPIE];
   sptie   = src1_reg[`SPTIE];
   ssoe    = src1_reg[`SSOE];

   spiswai_o = src2_reg[`SPISWAI];
   modfen    = src2_reg[`MODFEN];

   sppr_o = {sbrr_reg[`SPPR2], sbrr_reg[`SPPR1], sbrr_reg[`SPPR0]};
   spr_o  = {sbrr_reg[`SPR2],  sbrr_reg[`SPR1],  sbrr_reg[`SPR0]};
   spi_mode_o = spi_present_state;
end

endmodule 
