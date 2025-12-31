`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/18 10:43:29
// Design Name: 
// Module Name: amp_multiply
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


module amp_multiply(
input clk_fs,
input rst_n,
input ctr_done,

input [15:0] amp_gain,
input signed [16:0] data_sin,

output reg data_dac_done,
output reg [15:0] data_dac_out
    );


reg cnt_flag;
reg  [1:0] cnt;
reg signed [31:0] data_dac_out_reg;

always @(posedge clk_fs or negedge rst_n) begin
    if (!rst_n) begin
        data_dac_out_reg <= 16'b0;
        data_dac_done <= 1'b0;
        cnt_flag <= 1'b0;
    end
    else if (ctr_done) begin
        data_dac_out_reg <= data_sin * $signed(amp_gain);
        cnt_flag <= 1'b1;
    end
    else if (cnt == 2'd3) begin
        data_dac_out <= data_dac_out_reg[31:16];
        data_dac_done <= 1'b1;
        cnt_flag <= 1'b0;
    end
    else begin
        data_dac_out <= data_dac_out;
        cnt_flag <= 1'b0;
    end
end

always @(posedge clk_fs or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 2'b0;
    end
    else if (cnt_flag) begin
        cnt <= cnt + 1'b1;
    end
    else begin
        cnt <= 2'b0;
    end
end
endmodule
