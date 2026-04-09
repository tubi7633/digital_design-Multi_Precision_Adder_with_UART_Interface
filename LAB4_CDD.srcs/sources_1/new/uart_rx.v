`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2025 12:10:55 PM
// Design Name: 
// Module Name: uart_rx
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


module uart_rx #(
parameter   CLK_FREQ      = 125_000_000,
parameter   BAUD_RATE     = 115_200,
// Example: 125 MHz Clock / 115200 baud UART -> CLKS_PER_BIT = 1085 
parameter   CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE
)
(
input wire        iClk, iRst,
input wire        iRxSerial,
output wire [7:0] oRxByte, 
output wire       oRxDone
);

//states
localparam Sidle = 3'b000;
localparam Sstart = 3'b001;
localparam Sdata = 3'b010;
localparam Sstop = 3'b011;
localparam Sdone = 3'b100;

//registers for fsm
reg[2:0] rfsm_curr, rfsm_next;

//registers for counter
reg[$clog2(CLKS_PER_BIT):0] rcnt_curr, rcnt_next;

//registers for data bits
reg[2:0] rbit_curr, rbit_next;

reg[7:0] rRx_curr, rRx_next;

reg rRxDone;

// Double-register the input wire to prevent metastability issues
reg rRx1, rRx2;

always @(posedge iClk)
begin
    rRx1 <= iRxSerial;
    rRx2 <= rRx1;
end

always @(posedge iClk)
begin
    if (iRst == 1)
    begin
        rfsm_curr <= Sidle;
        rcnt_curr <= 0;
        rbit_curr <= 0;
        rRx_curr <= 0;
        rRxDone <= 0;
    end
    else
    begin
        rfsm_curr <= rfsm_next;
        rcnt_curr <= rcnt_next;
        rbit_curr <= rbit_next;
        rRx_curr <= rRx_next;
        rRxDone   <= (rfsm_curr == Sdone);
    end
end

always @(*)
begin

rfsm_next = rfsm_curr;
rbit_next = rbit_curr;
rcnt_next = rcnt_curr;
rRx_next = rRx_curr;

    case (rfsm_curr)
        Sidle: 
            begin
            //rRxDone = 0;
            if(rRx2 == 0)
                begin
                rcnt_next = 0;
                rfsm_next = Sstart;
                end
            else rfsm_next = Sidle;
            end
            
        Sstart: 
            begin
            if (rcnt_curr == CLKS_PER_BIT - 1)
                begin
                rcnt_next = 0;
                rbit_next = 0;
                rfsm_next = Sdata;
                end
            else
                begin
                rcnt_next = rcnt_curr + 1;
                rfsm_next = Sstart;
                end
            end
            
        Sdata: 
            begin
            if (rcnt_curr == (CLKS_PER_BIT / 2))
                begin
                rRx_next = {rRx2, rRx_curr[7:1]};
                end
            if (rcnt_curr == CLKS_PER_BIT - 1)
                begin
                rcnt_next = 0;
                if (rbit_curr == 7) rfsm_next = Sstop;
                else
                    begin
                    rbit_next = rbit_curr + 1;
                    rfsm_next = Sdata;
                    end
                end
            else 
                begin
                rcnt_next = rcnt_curr + 1;
                rfsm_next = Sdata;
                end
            end
         
        Sstop:
            begin
            if (rcnt_curr == CLKS_PER_BIT - 1) rfsm_next = Sdone;
            else 
                begin
                rcnt_next = rcnt_curr + 1;
                rfsm_next = Sstop;
                end
            end
        
        Sdone:
            begin
           // rRxDone = 1;
            rfsm_next = Sidle;
            end    
        
        default: rfsm_next = Sidle;
        
    endcase
end

assign oRxDone = rRxDone;
assign oRxByte = rRx_curr;

endmodule