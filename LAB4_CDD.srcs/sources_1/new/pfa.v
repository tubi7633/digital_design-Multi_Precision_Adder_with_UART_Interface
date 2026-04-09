`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.05.2025 16:34:33
// Design Name: 
// Module Name: pfa
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

module pfa (
  input  wire A,
  input  wire B,
  input  wire Cin,
  output wire Sum,
  output wire P,       // propagate = A?B
  output wire G        // generate  = A&B
);
  assign P   = A ^ B;
  assign G   = A & B;
  assign Sum = P ^ Cin;
endmodule
