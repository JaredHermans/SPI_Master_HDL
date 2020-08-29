///////////////////////////////////////////////////////////////////////
//              Jared Hermans
///////////////////////////////////////////////////////////////////////
// Description: SPI (Serial Peripheral Interface) Master with one chip-
//              select (AKA Slave Select) capability.
//
//              Supports arbitrary length byte transfers.
//
//              Instantiates a SPI Master and adds a single chip select.
//              If muptiple CS signals are need, use a different module
//              or use a multiplexer from a higher level
//
// Note:        i_Clk must be at least 2x faster than i_SPI_Clk
//
// Parameters:  SPI_MODE can be 0, 1, 2, or 3:
//              Mode | Clock Polarity (CPOL/CKP) | Clock Phase (CPHA)
//              0    |          0                |          0
//              1    |          0                |          1
//              2    |          1                |          0
//              3    |          1                |          1
//
//              CLKS_PER_HALF_BIT Sets frequency of o_SPO_Clk. which is
//              derived from i_Clk. EX: 100MHz i_Clk, CLKS_PER_HALF_BIT
//              = 2 would create o_SPI_CLK of 25 MHz. Must be >= 2
//
//              Max_Bytes_Per_CS = Set to the maximum number of bytes 
//              that will be sent during a single CS-low pulse.
//
//              CS_INACTIVE_CLKS - Sets the amount of time in clock 
//              cycles to hold the state of Chip-Select high (inactive)
//              before next command is allowed on the line. This is 
//              useful if the chip requires some time when CS is high
//              between transfers.
///////////////////////////////////////////////////////////////////////

module SPI_Master_With_Chip_Select #(
    parameter                           SPI_MODE = 0,
    parameter                           CLKS_PER_HALF_BIT = 2,
    parameter                           MAX_BYTES_PER_CS = 2,
    parameter                           CS_INACTIVE_CLKS = 1
) (
    // Control/Data Signals,
    input                                       i_Rst_L,        //FPGA Reset
    input                                       i_Clk,          //FPGA Clock

    // TX (MOSI) Signals
    input [$clog2(MAX_BYTES_PER_CS + 1) - 1:0]  i_TX_Count,     // #bytes per CS low
    input [7:0]                                 i_TX_Byte,      // Byte to transmit on MOSI
    input                                       i_TX_DV,        // Data Valid Pulse with i_TX_Byte
    output                                      o_TX_Ready,     //Transmit Ready for next byte

    // RX (MISO) Signals
    output reg [$clog2(MAX_BYTES_PER_CS+1)-1:0] o_RX_Count,     // Index RX byte
    output                                      o_RX_DV,        //Data Valid pulse (1 clock cycle)
    output [7:0]                                o_RX_Byte,      //Byte recieved on MISO

    //SPI Interface
    output                                      o_SPI_Clk,
    input                                       i_SPI_MISO,
    output                                      o_SPI_MOSI,
    output                                      o_SPI_CS_n
);

    localparam                                  IDLE        = 2'b00;
    localparam                                  TRANSFER    = 2'b01;
    localparam                                  CS_INACTIVE = 2'b10;

    reg [1:0]                                   r_SM_CS;
    reg                                         r_CS_n;
    reg [$clog2(CS_INACTIVE_CLKS) - 1:0]        r_CS_Inactive_Count;
    reg [$clog2(CS_INACTIVE_CLKS) - 1:0]        r_TX_Count;
    wire                                        w_Master_Ready;

    //Instantiate Master
    SPI_Master #(
        .SPI_MODE                               (SPI_MODE),
        .CLKS_PER_HALF_BIT                      (CLKS_PER_HALF_BIT)
    )
    SPI_Master_Inst (
        .i_Rst_L                                (i_Rst_L),      // FPGA Reset 
        .i_Clk                                  (i_Clk),        // FPGA Clock

        //TX (MOSI) Signals
        .i_TX_Byte                              (i_TX_Byte),    //Byte to transmit
        .i_TX_DV                                (i_TX_DV),      //Data Valid Pulse
        .o_TX_Ready                             (w_Master_Ready), //Transmit Ready for Byte

        //RX (MISO) Signals
        .o_RX_DV                                (o_RX_DV),      // Data Valid pulse (1 clock cycle)
        .o_RX_Byte                              (o_RX_Byte),    //Byte recieved on MISO

        // SPI Interface
        .o_SPI_Clk                              (o_SPI_Clk),
        .i_SPI_MISO                             (i_SPI_MISO),
        .o_SPI_MOSI                             (o_SPI_MOSI)
    );


    // Purpose: Control CS line using state machine
    always @(posedge i_Clk or negedge i_Rst_L) begin
        if (~i_Rst_L) begin
            r_SM_CS <= IDLE;
            r_CS_n  <= 1'b1;        // Resets to high
            r_TX_Count <= 0;
            r_CS_Inactive_Count <= CS_INACTIVE_CLKS;
        end
        else begin
            
            case (r_SM_CS)
            IDLE : begin
                if (r_CS_n & i_TX_DV) begin // Start of transmission
                    r_TX_Count  <= i_TX_Count - 1;       // Register TX Count
                    r_CS_n      <= 1'b0;                // Drive CS low
                    r_SM_CS     <= TRANSFER;            //Transfer bytes     
                end
            end
            
            TRANSFER: begin
                //Wait until SPI is done transferring to do next thing
                if (w_Master_Ready) begin
                    if (r_TX_Count > 0) begin
                        if (i_TX_DV)
                            r_TX_Count <= r_TX_Count - 1;
                    end
                    else begin
                        r_CS_n <= 1'b1;         // Done so set CS high
                        r_CS_Inactive_Count <= CS_INACTIVE_CLKS;
                        r_SM_CS <= CS_INACTIVE;
                    end                 
                end
            end 

            CS_INACTIVE: begin
                if (r_CS_Inactive_Count > 0)
                    r_CS_Inactive_Count <= r_CS_Inactive_Count - 1'b1;
                else 
                    r_SM_CS <= IDLE;
            end

            default : begin
                r_CS_n <= 1'b1; // Done so set CS high
                r_SM_CS <= IDLE; 
            end         
            endcase
        end
    end 


    // Purpose: Keep track of RX_Count
    always @(posedge i_Clk) begin
        if (r_CS_n)
            o_RX_Count <= 0;
        else if (o_RX_DV)
            o_RX_Count <= o_RX_Count + 1'b1; 
    end

    assign o_SPI_CS_n = r_CS_n;

    assign o_TX_Ready = ((r_SM_CS == IDLE) | (r_SM_CS == TRANSFER && w_Master_Ready == 1'b1 && r_TX_Count > 0)) & ~i_TX_DV;

endmodule