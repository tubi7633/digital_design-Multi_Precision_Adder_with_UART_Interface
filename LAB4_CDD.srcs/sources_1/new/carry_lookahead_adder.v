`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.05.2025
// Design Name: 
// Module Name: carry_lookahead_adder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Parameterized Kogge-Stone carry-lookahead adder
//              Automatically uses ceil(log2(WIDTH)) levels.
// 
//////////////////////////////////////////////////////////////////////////////////

module carry_lookahead_adder #(
  parameter integer WIDTH  = 256,
  // compute number of prefix stages needed
  parameter integer STAGES = $clog2(WIDTH)
)(
  input  wire [WIDTH-1:0] iA,
  input  wire [WIDTH-1:0] iB,
  input  wire             iCin,
  output wire [WIDTH-1:0] oSum,
  output wire             oCout
);

  // ---- 1) generate bitwise Propagate/Generate ----
  wire [WIDTH-1:0] P0, G0;
  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin : GEN_PFA
      pfa pfa_i (
        .A (iA[i]),
        .B (iB[i]),
        .Cin(),
        .Sum(),
        .P (P0[i]),
        .G (G0[i])
      );
    end
  endgenerate

  // ---- 2) build arrays of intermediate P/G ----
  //    G[k][j], P[k][j] = after k-th prefix stage
  //    stage 0 is just the bitwise G0,P0
  wire [WIDTH-1:0] G [0:STAGES];
  wire [WIDTH-1:0] P [0:STAGES];

  // stage 0
  assign G[0] = G0;
  assign P[0] = P0;

  // prefix stages k=1..STAGES
  genvar k;
  generate
    for (k = 1; k <= STAGES; k = k + 1) begin : PREFIX_STAGE
      localparam integer SPAN = 1 << (k-1);
      for (i = 0; i < WIDTH; i = i + 1) begin : BIT_LOOP
        if (i < SPAN) begin
          assign G[k][i] = G[k-1][i];
          assign P[k][i] = P[k-1][i];
        end else begin
          assign G[k][i] = G[k-1][i] 
                         | (P[k-1][i] & G[k-1][i-SPAN]);
          assign P[k][i] = P[k-1][i] & P[k-1][i-SPAN];
        end
      end
    end
  endgenerate

  // ---- 3) incorporate the true iCin to form carries ----
  // C[0] = iCin, C[j+1] = carry into bit j
  wire [WIDTH:0] C;
  assign C[0] = iCin;
  genvar j;
  generate
    for (j = 0; j < WIDTH; j = j + 1) begin : FORM_C
      // after STAGES of prefix, G[STAGES][j] is generate-with-zero-cin
      // and P[STAGES][j] is propagate
      assign C[j+1] = G[STAGES][j] 
                    | (P[STAGES][j] & iCin);
    end
  endgenerate

  // ---- 4) form sums ----
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin : DRIVE_SUM
      assign oSum[i] = P0[i] ^ C[i];
    end
  endgenerate
  assign oCout = C[WIDTH];

endmodule
