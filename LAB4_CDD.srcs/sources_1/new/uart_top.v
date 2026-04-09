`timescale 1ns / 1ps

module uart_top #(
    parameter OPERAND_WIDTH = 512,
    parameter ADDER_WIDTH   = 256,
    parameter NBYTES        = OPERAND_WIDTH / 8,
    parameter CLK_FREQ      = 125_000_000,
    parameter BAUD_RATE     = 115_200
)(
    input  wire iClk,
    input  wire iRst,
    input  wire iRx,
    output wire oTx
);

  // Registers for operands
  reg [OPERAND_WIDTH-1:0] rA;
  reg [OPERAND_WIDTH-1:0] rB;

  // FSM States
  localparam s_IDLE     = 3'b000,
             s_RX_OP    = 3'b111,
             s_WAIT_RX  = 3'b001,
             s_RX       = 3'b010,
             s_ADD      = 3'b110,
             s_TX       = 3'b011,
             s_WAIT_TX  = 3'b100,
             s_DONE     = 3'b101;

  reg [2:0] rFSM;
  reg        rOp; 

  // UART TX Control
  reg       rTxStart;
  reg [7:0] rTxByte;
  wire      wTxBusy, wTxDone;

  uart_tx #( .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE) ) UART_TX_INST (
    .iClk(iClk),
    .iRst(iRst),
    .iTxStart(rTxStart),
    .iTxByte(rTxByte),
    .oTxSerial(oTx),
    .oTxBusy(wTxBusy),
    .oTxDone(wTxDone)
  );

  // Adder signals
  reg  rStart;
  wire wDone;
  wire [OPERAND_WIDTH:0] wResult;

  mp_adder #(
    .OPERAND_WIDTH(OPERAND_WIDTH),
    .ADDER_WIDTH(ADDER_WIDTH)
  ) MP_ADDER_INST (
    .iClk(iClk),
    .iRst(iRst),
    .iOp(rOp),
    .iStart(rStart),
    .iOpA(rA),
    .iOpB(rB),
    .oRes(wResult),
    .oDone(wDone)
  );

  // UART RX
  wire       wRxDone;
  wire [7:0] wRxByte;

  uart_rx #( .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) UART_RX_INST (
    .iClk(iClk),
    .iRst(iRst),
    .iRxSerial(iRx),
    .oRxByte(wRxByte),
    .oRxDone(wRxDone)
  );

  // Byte counter
  reg [$clog2(2*NBYTES+1):0] rCnt;

  // Result TX buffer
  reg [(NBYTES+1)*8-1:0] rTxBuffer;
  

  // FSM
  always @(posedge iClk) begin
    if (iRst) begin
      rFSM <= s_IDLE;
      rTxStart <= 0;
      rOp       <= 0;
      rCnt <= 0;
      rA <= 0;
      rB <= 0;
      rStart <= 0;
      rTxByte <= 0;
      rTxBuffer <= 0;
    end else begin
      case (rFSM)
        s_IDLE: begin
          rFSM <= s_RX_OP;
        end
        
        s_RX_OP: begin
        if (wRxDone) begin
          rOp  <= wRxByte[0];     // only LSB matters
          rCnt <= 0;
          rFSM <= s_WAIT_RX;
        end
      end

        s_WAIT_RX: begin
          if (wRxDone) begin
            if (rCnt < NBYTES)
              rA <= {rA[OPERAND_WIDTH-9:0], wRxByte};
            else
              rB <= {rB[OPERAND_WIDTH-9:0], wRxByte};

            rCnt <= rCnt + 1;
            rFSM <= s_RX;
          end
        end

        s_RX: begin
          if (rCnt == 2*NBYTES) begin
            if (rOp) rB <= ~rB;  // Invert B for subtraction
            rStart <= 1;
            rFSM <= s_ADD;
          end else begin
            rFSM <= s_WAIT_RX;
          end
        end

        s_ADD: begin
          rStart <= 0;
          if (wDone) begin
            // The mp_adder already handles the +1 for subtraction via carry_in
            // so we don't need to add 1 again here
            if (rOp == 0) begin
            rTxBuffer <= wResult;
            end
            else begin
            rTxBuffer <= wResult[OPERAND_WIDTH-1:0];
            end
            
            rCnt <= 0;
            rFSM <= s_TX;
          end
        end

        s_TX: begin
        if(!rOp)begin
        
        
          if (rCnt < (NBYTES + 1) && !wTxBusy) begin
            // Extract the most significant byte properly
            
            rTxByte <= rTxBuffer >> ((NBYTES+1-1-rCnt)*8);
          
            rTxStart <= 1;
            rCnt <= rCnt + 1;
            rFSM <= s_WAIT_TX;
          end
          
           else if (rCnt == (NBYTES + 1)) begin
            rFSM <= s_DONE;
            rTxStart <= 0;
          end
          
          
        end
        
        else begin
        
        if (rCnt < NBYTES) begin
          rTxByte  <= rTxBuffer >> ((NBYTES-1 - rCnt)*8);
          rCnt     <= rCnt + 1;
          rTxStart <= 1;
          rFSM     <= s_WAIT_TX;
        end else begin
          rFSM     <= s_DONE;
          rTxStart <= 0;
        end
        
        end
        end

        s_WAIT_TX: begin
          if (wTxDone) begin
            rFSM <= s_TX;
            rTxStart <= 0;
          end
        end

        s_DONE: begin
          // Hold state or go to IDLE to restart
          rFSM <= s_DONE;
        end

        default: rFSM <= s_IDLE;
      endcase
    end
  end

endmodule