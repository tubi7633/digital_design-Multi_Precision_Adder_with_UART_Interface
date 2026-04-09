`timescale 1ns / 1ps

module uart_top_TB();

  // Simulation parameters
  localparam OPERAND_WIDTH = 32;  // 4 bytes
  localparam ADDER_WIDTH   = 16;
  localparam CLK_FREQ      = 100;
  localparam BAUD_RATE     = 10;
  localparam NBYTES        = OPERAND_WIDTH / 8;
  localparam CLK_PERIOD    = 20;

  // Signals
  reg rClk = 0;
  reg rRst = 0;
  wire wTx;
  wire wRx = 1'b1;  // RX is not used

  // Instantiate DUT
  uart_top #(
    .OPERAND_WIDTH(OPERAND_WIDTH),
    .ADDER_WIDTH(ADDER_WIDTH),
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) DUT (
    .iClk(rClk),
    .iRst(rRst),
    .iRx(wRx),
    .oTx(wTx)
  );

  // Clock
  always #(CLK_PERIOD / 2) rClk = ~rClk;

  // Test vectors
  reg [OPERAND_WIDTH-1:0] testA, testB;
  reg [OPERAND_WIDTH:0]   expectedResult;
  integer i;

  initial begin
    $display("\n===== UART_TOP TestBench START =====\n");

    // Assign known test operands
    testA = 32'h11223344;
    testB = 32'h01010101;
    expectedResult = testA + testB;

    $display("Initial Test Inputs:");
    $display("A               = 0x%08h", testA);
    $display("B               = 0x%08h", testB);
    $display("Expected Result = 0x%09h", expectedResult);
    $display("");

    // Reset
    rRst = 1;
    #(5 * CLK_PERIOD);
    rRst = 0;
    #(5 * CLK_PERIOD);

    // Inject operands
    DUT.rA     = testA;
    DUT.rB     = testB;
    DUT.rStart = 1;
    DUT.rFSM   = DUT.s_ADD;

    #(CLK_PERIOD);
    DUT.rStart = 0;

    // Wait for computation
    wait(DUT.wDone == 1);
    #(CLK_PERIOD);

    $display("Adder Done:");
    $display("wResult        = 0x%09h", DUT.wResult);
    $display("");

    // Load into TX buffer
   DUT.rTxBuffer = DUT.wResult << ((8 * (NBYTES + 1)) - (OPERAND_WIDTH + 1));



    DUT.rCnt = 0;
    DUT.rFSM = DUT.s_TX;

    $display("TX Buffer      = 0x%0h", DUT.rTxBuffer);
    $display("Expected Byte Count = %0d", NBYTES + 1);
    $display("");

    // Debug print each byte from TX buffer
    for (i = 0; i < (NBYTES + 1); i = i + 1) begin
      $display("Byte[%0d] = 0x%02x", i, (DUT.rTxBuffer >> ((NBYTES - i) * 8)) & 8'hFF);
    end

    // Simulate transmission behavior
    for (i = 0; i < (NBYTES + 1); i = i + 1) begin
      wait (DUT.wTxBusy == 0);
     DUT.rTxByte = (DUT.rTxBuffer >> ((NBYTES - i) * 8)) & 8'hFF;

      DUT.rTxStart = 1;
      #(CLK_PERIOD);
      DUT.rTxStart = 0;

      $display("Sent Byte[%0d] = 0x%02x", i, DUT.rTxByte);

      DUT.rCnt = DUT.rCnt + 1;
      #(2 * CLK_PERIOD);
    end

    $display("\n===== UART_TOP TestBench DONE =====");
    $stop;
  end

endmodule
