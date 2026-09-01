module spi_master_level_block
#(
parameter ADDR_WIDTH     = 3,
parameter DATA_WIDTH     = 8,
parameter APB_ADDR_WIDTH = 3,
parameter APB_DATA_WIDTH = 8,
parameter SPI_DATA_WIDTH = 8
)
(
input                       pclk,
input                       preset_n,
input      [ADDR_WIDTH-1:0] paddr,
input                       pwrite,
input                       psel,
input                       penable,
input      [DATA_WIDTH-1:0] pwdata,
output reg [DATA_WIDTH-1:0] prdata,
output reg                  pready,
output reg                  pslverr,
input                       miso,
input                       ss_in,
output reg                  sclk,
output reg                  ss,
output reg                  spi_interrupt_request,
output reg                  mosi
);

reg [APB_ADDR_WIDTH-1:0] paddr_w;
reg                      psel_w;
reg                      pwrite_w;
reg                      penable_w;
reg [APB_DATA_WIDTH-1:0] pwdata_w;
reg                      miso_w;

wire                      sclk_w;
wire                      ss_w;
wire                      receive_data_w;
wire                      tip_w;
wire [APB_DATA_WIDTH-1:0] prdata_w;
wire                      mstr_w;
wire                      cpol_w;
wire                      cpha_w;
wire                      lsbfe_w;
wire                      spiswai_w;
wire [2:0]                sppr_w;
wire [2:0]                spr_w;
wire                      spi_interrupt_request_w;
wire                      pready_w;
wire                      pslverr_w;
wire                      send_data_w;
wire [1:0]                spi_mode_w;
wire [SPI_DATA_WIDTH-1:0] data_mosi_w;        
wire [SPI_DATA_WIDTH-1:0] data_miso_w;         
wire                      mosi_w;
wire [11:0]               baud_rate_divisor_w;
wire                      miso_receive_sclk_w;
wire                      miso_receive_sclk0_w;
wire                      miso_send_sclk_w;
wire                      miso_send_sclk0_w;

always @(*)
begin
   paddr_w    = paddr;
   pwrite_w   = pwrite;
   psel_w     = psel;
   penable_w  = penable;
   pwdata_w   = pwdata;
end

always @(*)
begin
   prdata  = prdata_w;
   pready  = pready_w;
   pslverr = pslverr_w;
end

always @(*)
begin
   miso_w = miso;
end

always @(*)
begin
   sclk                  = sclk_w;
   ss                    = ss_w;
   spi_interrupt_request = spi_interrupt_request_w;
   mosi                  = mosi_w;
end

spi_clock_gen             spi_clk_gen_block
(
.pclk                     (pclk),
.preset_n                 (preset_n),
.spi_mode_i               (spi_mode_w),
.spiswai_i                (spiswai_w),
.sppr_i                   (sppr_w),
.spr_i                    (spr_w),
.cpol_i                   (cpol_w),
.cpha_i                   (cpha_w),
.ss_i                     (ss_w),
.sclk_o                   (sclk_w),            
.miso_receive_sclk_o      (miso_receive_sclk_w),
.miso_receive_sclk0_o     (miso_receive_sclk0_w),
.miso_send_sclk_o         (miso_send_sclk_w),
.miso_send_sclk0_o        (miso_send_sclk0_w),
.baud_rate_divisor_o      (baud_rate_divisor_w)
);

shift_reg                 shift_reg_block
(
.pclk                     (pclk),
.preset_n                 (preset_n),
.ss_i                     (ss_w),
.send_data_i              (send_data_w),
.lsbfe_i                  (lsbfe_w),
.cpha_i                   (cpha_w),
.cpol_i                   (cpol_w),
.miso_receive_sclk_i      (miso_receive_sclk_w),
.miso_receive_sclk0_i     (miso_receive_sclk0_w),
.mosi_send_sclk_i         (miso_send_sclk_w),   
.mosi_send_sclk0_i        (miso_send_sclk0_w), 
.data_mosi_i              (data_mosi_w),
.miso_i                   (miso_w),
.receive_data_i           (receive_data_w),
.mosi_o                   (mosi_w),
.data_miso_o              (data_miso_w)
);

apb_slave_interface       apb_slave_interface_block
(
.pclk                     (pclk),
.preset_n                 (preset_n),
.paddr_i                  (paddr_w),
.pwrite_i                 (pwrite_w),
.psel_i                   (psel_w),
.penable_i                (penable_w),
.pwdata_i                 (pwdata_w),           
.ss_i                     (ss_in),
.miso_data_i              (data_miso_w),         
.receive_data_i           (receive_data_w),
.tip_i                    (tip_w),
.prdata_o                 (prdata_w),
.mstr_o                   (mstr_w),
.cpol_o                   (cpol_w),
.cpha_o                   (cpha_w),
.lsbfe_o                  (lsbfe_w),
.spiswai_o                (spiswai_w),
.sppr_o                   (sppr_w),
.spr_o                    (spr_w),
.spi_interrupt_request_o  (spi_interrupt_request_w),
.pready_o                 (pready_w),
.pslverr_o                (pslverr_w),
.send_data_o              (send_data_w),
.mosi_data_o              (data_mosi_w),        
.spi_mode_o               (spi_mode_w)
);

spi_slave_control_select  spi_slave_control_select_block
(
.pclk                     (pclk),
.preset_n                 (preset_n),
.mstr_i                   (mstr_w),
.spiswai_i                (spiswai_w),
.spi_mode_i               (spi_mode_w),
.send_data_i              (send_data_w),        
.baud_rate_divisor_i      (baud_rate_divisor_w),
.receive_data_o           (receive_data_w),
.ss_o                     (ss_w),
.tip_o                    (tip_w)
);

endmodule
