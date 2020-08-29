/////////////////////////////////////////////////////////////////
// Description: Testbench for SPI Master with Chip Select
/////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module SPI_Master_With_Chip_Select_TB ();

    parameter       SPI_MODE            = 3;    // CPOL = 1, CPHA = 1
    parameter       CLKS_PER_HALF_BIT   = 4;    // 6.25 MHz
    parameter       MAIN_CLK_DELAY      = 2;    // 25 MHz
    parameter       MAX_BYTES_PER_CS    = 2;    // 2 bytes per chip select
    parameter       CS_INACTIVE_CLKS    = 10;   // Adds delay between bytes

    logic           r_Rst_L             = 1'b0;
    logic           w_SPI_Clks;
    logic           r_SPI_En            = 1'b0;
    logic           r_Clk               = 1'b0;
    logic           w_SPI_CS_n;
    logic           w_SPI_MOSI;

    //Master Specific
    logic [7:0]     r_Master_TX_Byte    = 0;
    logic           r_Master_TX_DV      = 1'b0;
    logic           w_Master_TX_Ready;
    logic           w_Master_RX_DV;
    logic [7:0]     w_Master_RX_Byte;
    logic [$clog2(MAX_BYTES_PER_CS + 1) - 1:0] w_Master_RX_Count, r_Master_TX_Count = 2'b10;

    // Clock Generators: 
    always #(MAIN_CLK_DELAY) r_Clk = ~r_Clk;

    // Instantiate UUT
    SPI_Master_With_Chip_Select #(
        .SPI_MODE                   (SPI_MODE),
        .CLKS_PER_HALF_BIT          (CLKS_PER_HALF_BIT),
        .MAX_BYTES_PER_CS           (MAX_BYTES_PER_CS),
        .CS_INACTIVE_CLKS           (CS_INACTIVE_CLKS)
    )
    Inst (
        // Control/Data Signals
        .i_Rst_L                    (r_Rst_L),      //FPGA Reset
        .i_Clk                      (r_Clk),        //FPGA Clock

        //TX (MOSI) Signals
        .i_TX_Count                 (r_Master_TX_Count),    // Number of bytes per CS
        .i_TX_Byte                  (r_Master_TX_Byte),     // Byte to transmit on MOSI
        .i_TX_DV                    (r_Master_TX_DV),       // Data Valid pulse with i_TX_Byte
        .o_TX_Ready                 (w_Master_TX_Ready),    // Transmit ready for byte

        // RX (MISO) Signals
        .o_RX_Count                 (w_Master_RX_Count),    // Index of RX byte
        .o_RX_DV                    (w_Master_RX_DV),       // Data Valid pulse (1 clock cycle)
        .o_RX_Byte                  (w_Master_RX_Byte),     // Byte recieved on MISO

        //SPI Interface
        .o_SPI_Clk                  (w_SPI_Clk),
        .i_SPI_MISO                 (w_SPI_MOSI),
        .o_SPI_MOSI                 (w_SPI_MOSI),
        .o_SPI_CS_n                 (w_SPI_CS_n)
    );

    // Sends a single byte from master. Will drive SC on its own.
    task SendSingleByte(input [8:0] data);
        @(posedge r_Clk);
        r_Master_TX_Byte <= data;
        r_Master_TX_DV   <= 1'b1;
        @(posedge r_Clk);
        r_Master_TX_DV   <= 1'b0;
        @(posedge r_Clk);
        @(posedge w_Master_TX_Ready);
    endtask

    initial begin
        repeat(10) @(posedge r_Clk);
        r_Rst_L = 1'b0;
        repeat(10) @(posedge r_Clk);
        r_Rst_L = 1'b1;

        // Test sending 2 bytes
        SendSingleByte(8'hC1);
        $display("Sent out 0xC1, Recieved 0x%X", w_Master_RX_Byte);
        SendSingleByte(8'hC2);
        $display("Sent out 0xC2, Recieved 0x%X", w_Master_RX_Byte);

        repeat(100) @(posedge r_Clk);
        $finish();
    end
endmodule