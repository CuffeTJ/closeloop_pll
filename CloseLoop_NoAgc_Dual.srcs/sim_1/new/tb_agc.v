`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/25 23:48:01
// Design Name: 
// Module Name: tb_agc
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

module tb_agc;

// agc Parameters
parameter PERIOD  = 10;


// agc Inputs
reg   clk_fs                               = 0 ;
reg   rst_n                                = 0 ;
reg   clk_amp_sa                           = 0 ;
reg   [15:0]  amp_from_pd                  = 16'd256 ;

// agc Outputs
wire  [15:0]  amp_gain                     ;


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
    #(PERIOD*800)  amp_from_pd = amp_from_pd+16'd10;
    #(PERIOD*800)  amp_from_pd = amp_from_pd-16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd+16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd-16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd+16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd-16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd+16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd-16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd+16'd20;
    #(PERIOD*800)  amp_from_pd = amp_from_pd-16'd20;
end

agc  u_agc (
    .clk_fs                  ( clk_fs              ),
    .rst_n                   ( rst_n               ),
    .clk_amp_sa              ( clk_amp_sa          ),
    .amp_from_pd             ( amp_from_pd  [15:0] ),

    .amp_gain                ( amp_gain     [15:0] )
);



endmodule