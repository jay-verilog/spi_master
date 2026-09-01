// SPI Control Register1
`define SPI_CONTROL_REGISTER1     3'b000
`define SPI_CONTROL_REGISTER1_RST 8'b0000_1000
`define SPIE                      3'b111
`define SPE                       3'b110
`define SPTIE                     3'b101
`define MSTR                      3'b100
`define CPOL                      3'b011
`define CPHA                      3'b010
`define SSOE                      3'b001
`define LSBFE                     3'b000

// SPI Control Register2
`define SPI_CONTROL_REGISTER2     3'b001
`define SPI_CONTROL_REGISTER2_RST 8'b0000_0000
`define MODFEN                    3'b100
`define BIDIROE                   3'b011
`define SPISWAI                   3'b001
`define SPC0                      3'b000

// SPI Baud Rate Register 
`define SPI_BAUD_RATE_REGISTER     3'b010
`define SPI_BAUD_RATE_REGISTER_RST 8'b0000_0000
`define SPPR2                      3'b110
`define SPPR1                      3'b101
`define SPPR0                      3'b100
`define SPR2                       3'b010
`define SPR1                       3'b001
`define SPR0                       3'b000

// SPI Status Register
`define SPI_STATUS_REGISTER        3'b011
`define SPI_STATUS_REGISTER_RST    8'b0010_0000
`define SPIF                       3'b111
`define SPTEF                      3'b101
`define MODF                       3'b100

// SPI data Register 
`define SPI_DATA_REGISTER          3'b100
`define SPI_DATA_REGISTER_RST      8'b0000_0000
`define BIT7                       3'b111
`define BIT6                       3'b110
`define BIT5                       3'b101
`define BIT4                       3'b100
`define BIT3                       3'b011
`define BIT2                       3'b010
`define BIT1                       3'b001
`define BIT0                       3'b000
