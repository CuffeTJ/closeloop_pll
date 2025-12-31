`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/25 13:49:14
// Design Name: 
// Module Name: tb_amp_sa
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


//~ `New testbench
`timescale  1ns / 1ps

module tb_amp_sa;

// amp_sa Parameters
parameter PERIOD  = 10;


// amp_sa Inputs
reg   clk_fs                               = 0 ;
reg   rst_n                                = 0 ;
reg   [15:0]  amp_from_pd                  = 16'd1 ;

// amp_sa Outputs
wire  [15:0]  amp_sa                       ;
wire sa_done;

initial
begin
    forever #(PERIOD/2)  clk_fs=~clk_fs;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

initial
begin
    #(PERIOD*16) amp_from_pd                  = 16'd2 ;
end

amp_sa  u_amp_sa (
    .clk_fs                  ( clk_fs              ),
    .rst_n                   ( rst_n               ),
    .amp_from_pd             ( amp_from_pd  [15:0] ),

    .amp_sa                  ( amp_sa       [15:0] ),
    .sa_done                    (sa_done)
);



endmodule
