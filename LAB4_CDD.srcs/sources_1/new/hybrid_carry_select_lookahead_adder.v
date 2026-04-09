`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.05.2025
// Design Name: 
// Module Name: hybrid_carry_select_lookahead_adder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Hybrid adder: uses carry-lookahead within each BLOCK, and
//              carry-select between blocks.
// 
// Dependencies: carry_lookahead_adder.v
//               ripple_carry_adder_Nb.v (if you choose to use it elsewhere)
// 
//////////////////////////////////////////////////////////////////////////////////

module hybrid_carry_select_lookahead_adder #(
  parameter WIDTH  = 32,        // total adder width
  parameter BLOCK  = 8,         // bits per CLA block
  // compute number of blocks, rounding up
  parameter NBLOCKS = (WIDTH + BLOCK - 1) / BLOCK
)(
  input  wire [WIDTH-1:0] iA,
  input  wire [WIDTH-1:0] iB,
  input  wire             iCin,
  output wire [WIDTH-1:0] oSum,
  output wire             oCout
);

  // carry between blocks
  wire [NBLOCKS:0] carry_sel;
  assign carry_sel[0] = iCin;

  genvar i;
  generate
    for (i = 0; i < NBLOCKS; i = i + 1) begin : BLK
      // calculate this block's true width
      localparam integer W = (i < NBLOCKS-1)
                              ? BLOCK
                              : (WIDTH - (NBLOCKS-1)*BLOCK);

      // slice the inputs for this block
      wire [W-1:0] A_blk = (i < NBLOCKS-1)
                            ? iA[ i*BLOCK +: W ]
                            : iA[ WIDTH-1 : (NBLOCKS-1)*BLOCK ];
      wire [W-1:0] B_blk = (i < NBLOCKS-1)
                            ? iB[ i*BLOCK +: W ]
                            : iB[ WIDTH-1 : (NBLOCKS-1)*BLOCK ];

      // two parallel CLAs: one assuming carry-in = 0, one = 1
      wire [W-1:0] sum0, sum1;
      wire         c0, c1;

      carry_lookahead_adder #(.WIDTH(W)) cla0 (
        .iA   (A_blk),
        .iB   (B_blk),
        .iCin (1'b0),
        .oSum (sum0),
        .oCout(c0)
      );
      carry_lookahead_adder #(.WIDTH(W)) cla1 (
        .iA   (A_blk),
        .iB   (B_blk),
        .iCin (1'b1),
        .oSum (sum1),
        .oCout(c1)
      );

      // select the correct sums & carry-out based on actual carry_sel[i]
      if (i < NBLOCKS-1) begin
        assign oSum[ i*BLOCK +: W ]   = carry_sel[i] ? sum1 : sum0;
      end else begin
        assign oSum[ WIDTH-1 : (NBLOCKS-1)*BLOCK ] 
                                       = carry_sel[i] ? sum1 : sum0;
      end

      // propagate the carry to the next block
      assign carry_sel[i+1] = carry_sel[i] ? c1 : c0;
    end
  endgenerate

  // final overall carry-out
  assign oCout = carry_sel[NBLOCKS];

endmodule
