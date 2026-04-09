`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2025 14:58:53
// Design Name: 
// Module Name: ripple_carry_adder_Nb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ripple_carry_adder_Nb #(
    parameter   ADDER_WIDTH = 16
    )
    (
    input   wire [ADDER_WIDTH-1:0]  iA, iB, 
    input   wire                    iCarry,
    output  wire [ADDER_WIDTH-1:0]  oSum, 
    output  wire                    oCarry
);


wire  [ADDER_WIDTH - 1:0] wCarry;

genvar i;

// Generate Full Adders for each bit
generate
    for (i = 0; i < ADDER_WIDTH; i = i + 1) begin : FA_LOOP
        if (i == 0) begin
            full_adder FA0 (
                .iA(iA[i]), .iB(iB[i]), .iCarry(iCarry),
                .oSum(oSum[i]), .oCarry(wCarry[i])
            );
        end else begin
            full_adder FAi (
                .iA(iA[i]), .iB(iB[i]), .iCarry(wCarry[i-1]),
                .oSum(oSum[i]), .oCarry(wCarry[i])
            );
        end
    end
endgenerate

// Assign final carry-out
assign oCarry = wCarry[ADDER_WIDTH-1];


endmodule
