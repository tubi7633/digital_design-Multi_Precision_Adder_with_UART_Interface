`timescale 1ns / 1ps
module carry_select_adder #(
  parameter ADDER_WIDTH = 256,
  parameter BLOCK       = 16,
  // number of full blocks (ceiling):
  parameter NBLOCKS     = (ADDER_WIDTH + BLOCK - 1) / BLOCK
)(
  input   wire [ADDER_WIDTH-1:0] iA,
  input   wire [ADDER_WIDTH-1:0] iB,
  input   wire                   iCarry,
  output  wire [ADDER_WIDTH-1:0] oSum,
  output  wire                   oCarry
);

  // carry chain
  wire [NBLOCKS:0] carry_sel;
  assign carry_sel[0] = iCarry;

  genvar i;
  generate
    for (i = 0; i < NBLOCKS; i = i + 1) begin : BLK
      // compute this block's true width:
      localparam WIDTH = (i < NBLOCKS-1)
                         ? BLOCK
                         : (ADDER_WIDTH - (NBLOCKS-1)*BLOCK);

      // pick the right bits of A and B:
      // full blocks use i*BLOCK +: WIDTH
      // last block uses top WIDTH bits of iA/iB
      wire [WIDTH-1:0] A_chunk = 
          (i < NBLOCKS-1)
            ? iA[ i*BLOCK +: WIDTH ]
            : iA[ ADDER_WIDTH-1 : (NBLOCKS-1)*BLOCK ];
      wire [WIDTH-1:0] B_chunk = 
          (i < NBLOCKS-1)
            ? iB[ i*BLOCK +: WIDTH ]
            : iB[ ADDER_WIDTH-1 : (NBLOCKS-1)*BLOCK ];

      // two parallel ripple adders per block
      wire [WIDTH-1:0] sum0, sum1;
      wire             c0, c1;

      ripple_carry_adder_Nb #(.ADDER_WIDTH(WIDTH)) add0 (
        .iA    (A_chunk), .iB(B_chunk),
        .iCarry(1'b0),
        .oSum  (sum0),   .oCarry(c0)
      );
      ripple_carry_adder_Nb #(.ADDER_WIDTH(WIDTH)) add1 (
        .iA    (A_chunk), .iB(B_chunk),
        .iCarry(1'b1),
        .oSum  (sum1),   .oCarry(c1)
      );

      // now map into the correct oSum bits:
      if (i < NBLOCKS-1) begin
        // full 6-bit slice
        assign oSum[ i*BLOCK + WIDTH-1 : i*BLOCK ] = 
                 carry_sel[i] ? sum1 : sum0;
      end else begin
        // last partial slice (2 bits for 32-bit total)
        assign oSum[ ADDER_WIDTH-1 : (NBLOCKS-1)*BLOCK ] = 
                 carry_sel[i] ? sum1 : sum0;
      end

      // chain the carry
      assign carry_sel[i+1] = carry_sel[i] ? c1 : c0;
    end
  endgenerate

  // final carry out
  assign oCarry = carry_sel[NBLOCKS];

endmodule
