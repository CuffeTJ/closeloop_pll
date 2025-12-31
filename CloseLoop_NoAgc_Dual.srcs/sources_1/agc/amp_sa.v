`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/24 22:08:33
// Design Name: 
// Module Name: amp_sa
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


module amp_sa(
input   clk_fs,
// input   clk_1M,
input   rst_n,
input   [15:0]  amp_from_pd,

output reg [15:0]  amp_sa,
output reg sa_done
    );


// localparam SA_CNT_MAX = 18'd100_000;
localparam SAMPLING_RATE_SPS = 1_000;
localparam F_CLK_HZ = 100_000_000;
localparam SA_CNT_MAX = F_CLK_HZ/SAMPLING_RATE_SPS;      
reg [17:0]  sa_cnt;
reg         sa_st;
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)  sa_cnt <= 17'b0;
    else        sa_cnt <= (sa_cnt==SA_CNT_MAX-1'b1) ? 17'b0 : sa_cnt+1'b1;
end
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)  sa_st <= 1'b0;
    else if(sa_cnt==SA_CNT_MAX-1'b1)    sa_st <= 1'b1;
    else        sa_st <= 1'b0;
end

reg [1:0]  state;
localparam  IDLE         = 2'b00,
            SA           = 2'b01,
            SA_VERI      = 2'b10;

reg [15:0] amp_d1, amp_d2, amp_d3;
reg [1:0] cnt1;
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        cnt1  <= 2'b00;
        amp_d1 <= 16'd0;
        amp_d2 <= 16'd0;
        amp_d3 <= 16'd0;
        amp_sa <= 16'd0;
        sa_done <= 1'b0;
    end
    else begin
        case(state)
            IDLE: begin
                sa_done <= 1'b0;
                if(sa_st)   state <= SA;
            end

            SA: begin
                amp_d1 <= amp_from_pd;
                amp_d2 <= amp_d1;
                amp_d3 <= amp_d2;
                cnt1 <= cnt1 + 1'b1;
                if(cnt1 == 2'd3) 
                    state <= SA_VERI;
            end

            SA_VERI: begin
                if(amp_d1 == amp_d3) begin
                    amp_sa <= amp_d3<<<4;
                    sa_done <= 1'd1;
                    state <= IDLE;
                end
                else 
                    state <= SA;
            end
        endcase
    end
end


endmodule
