`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/25 14:47:09
// Design Name: 
// Module Name: amp_ctr
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


module amp_ctr(
input clk_fs,
input rst_n,

input signed [15:0]  amp_sa,//max 2^15
input sa_done,

output reg [15:0] amp_gain,
output reg ctr_done 
    );

reg sa_do1, sa_do2, sa_do3;
wire ctr_st = sa_do2&(!sa_do3);
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        sa_do1 <= 1'b0;
        sa_do2 <= 1'b0;
        sa_do3 <= 1'b0;
    end
    else begin
        sa_do1 <= sa_done;
        sa_do2 <= sa_do1;
        sa_do3 <= sa_do2;     
    end   
end
                                   
localparam signed K1 = 16'd32604;  //Q1.15 real = K1/32768 = 1 - Ts/tau = 0.5~1
                                   //Ts = 0.0005~0.05(Fs = 2000~20);tau = 0.1~10(tau = 2Q/wn)
                                   //Typical Ts = 0.001(Fs = 1000), tau = 2, K1 = 0.995*32768 = 32764
localparam signed K2 = 16'd131;    //Q1.15 real = K2/32768 = K_D2A*Ts/tau = 0.0001~0.01
                                   //K_D2A: U2^9=>amp_sa2^12 = 2^3
                                   //Typical Ts = 0.001, tau = 2, K2 = 2^3 * 0.001/2 = 0.004(*32768)
localparam signed K12 = 16'd32441; //Q1.15 real = K12/32768 = (K1/32768)^2 = 0.25~1; 
                                   //Typical 0.995^2*32768 = 32441 
localparam signed Q = 16'd1000;    //PredictionVariance for CodeValue(Variance is ^2)
localparam signed R = 16'd4000;   //MeasurementVariance for CodeValue
localparam signed Ref = 16'd4096;  //Reference of amp_sa, typical 2^(8+4)=4096
localparam signed Kp = 16'd256;    //Q8.8 real = Kp/256
localparam signed Ki = 16'd256;    //Q4.12 real = Ki/4096

localparam  [3:0]   IDLE  = 4'd0,
                    STEP1 = 4'd1,
                    STEP2 = 4'd2,
                    STEP3 = 4'd3,
                    STEP4 = 4'd4,
                    STEP5 = 4'd5,
                    STEP6 = 4'd6,
                    DIVD  = 4'd13,
                    DONE  = 4'd14,
                    WAIT4 = 4'd15;
           
reg [3:0] state, state_next;
reg signed [15:0] Kk;   //Q1.15 real = Kk/32768 = (-1,1)
reg signed [15:0] v1,v2,v3,v4,v5,v6,v7;
reg signed [15:0] P, x_hat, x_hat_pre, P_pre;
reg signed [15:0] U0, U; ///////////////////////////////////////////////////U和K2的增益要仔细考虑
reg [1:0] cnt1;
reg signed [15:0] denominator, numerator;
wire signed[31:0] quotient;
reg div_start;
wire div_done;


wire signed [31:0] v1_temp = Kk*(amp_sa-x_hat_pre);//s1
wire signed [31:0] P_temp = $signed(16'd32768 - Kk)*P_pre;  

wire signed [15:0] x_hat_temp = x_hat_pre + v1;//s2
wire signed [15:0] v2_temp = Ref - x_hat_temp;

wire signed [31:0] v3_temp = Kp*v2;//s3
wire signed [31:0] v4_temp = Ki*v2;


wire signed [15:0] Ud_temp = v3+v4;//s4
// wire signed [31:0] v5_temp = K1*x_hat_pre;
wire signed [31:0] v5_temp = K1*x_hat;

wire signed [31:0] v6_temp = K2*U;//s5
wire signed [31:0] v7_temp = K12*P;

wire signed [15:0] x_hat_pre_temp = v5+v6;//s6
wire signed [15:0] P_pre_temp = v7+Q;
wire signed [15:0] denominator_temp = P_pre_temp+R;

div_gen_0 amp_div (
    .aclk(clk_fs),                              // input wire aclk
    .s_axis_divisor_tvalid(div_start),          // input wire s_axis_divisor_tvalid
    .s_axis_divisor_tready(),                   // output wire s_axis_divisor_tready
    .s_axis_divisor_tdata(denominator),         // input wire [15 : 0] s_axis_divisor_tdata
    .s_axis_dividend_tvalid(div_start),         // input wire s_axis_dividend_tvalid
    .s_axis_dividend_tready(),                  // output wire s_axis_dividend_tready
    .s_axis_dividend_tdata(numerator),          // input wire [15 : 0] s_axis_dividend_tdata
    .m_axis_dout_tvalid(div_done),              // output wire m_axis_dout_tvalid
    .m_axis_dout_tdata(quotient)                // output wire [31 : 0] m_axis_dout_tdata
);

always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        state_next <= IDLE;
        Kk <= 16'd32767;//
        x_hat_pre <= 16'b0;//       
        P_pre <= 16'b0;//        
        v1 <= 16'b0;
        P <= 16'b0;
        x_hat <= 16'b0;
        v2 <= 16'b0;
        v3 <= 16'b0;
        v4 <= 16'b0;
        U0 <= 16'd512; //前馈初值
        U <= 16'b0;
        v5 <= 16'b0;
        v6 <= 16'b0;
        v7 <= 16'b0;
        div_start <= 1'b0;
        numerator <= 16'd1;
        denominator <= 16'd1;
        amp_gain <= 16'b0;
        ctr_done <= 16'b0;
        cnt1 <= 16'b0;
    end
    else begin
        case(state)
            IDLE: begin
                ctr_done <= 1'b0;
                state_next <= IDLE;
                if(ctr_st == 1'b1) begin
                    state <= WAIT4;
                    state_next <= STEP1;                    
                end
            end
            STEP1: begin
                v1 <= {v1_temp[31], v1_temp[29:15]};
                P <= {P_temp[31], P_temp[29:15]};
                state <= WAIT4;
                state_next <= STEP2;
            end
            STEP2: begin
                x_hat <= x_hat_temp;
                v2 <= v2_temp;
                state <= WAIT4;
                state_next <= STEP3;
            end
            STEP3: begin
                v3 <= {v3_temp[31], v3_temp[22:8]};
                // v4 <= {v4_temp[31], v4_temp[26:12]};
                v4 <= {v4_temp[31], v4_temp[26:12]} + v4;
                state <= WAIT4;
                state_next <= STEP4;
            end
            STEP4: begin
                U <= Ud_temp + U0;
                v5 <= {v5_temp[31], v5_temp[29:15]};
                state <= WAIT4;
                state_next <= STEP5;
            end
            STEP5: begin
                v6 <= {v6_temp[31], v6_temp[29:15]};
                v7 <= {v7_temp[31], v7_temp[29:15]};
                state <= WAIT4;
                state_next <= STEP6;
            end
            STEP6: begin
                x_hat_pre <= x_hat_pre_temp;
                P_pre <= P_pre_temp;
                numerator <= P_pre_temp;
                denominator <= denominator_temp;
                div_start <= 1'b1;
                state <= WAIT4;
                state_next <= DIVD;
            end
            DIVD: begin
                div_start <= 1'b0;
                if(div_done == 1'b1) begin
                    Kk <= {quotient[31],quotient[15:1]};
                    state <= DONE;
                end
            end
            DONE: begin
                amp_gain <= U;
                ctr_done <= 1'b1;
                state <= IDLE;
            end
            WAIT4: begin
                cnt1 <= cnt1 + 1'b1;
                if(cnt1 == 2'd3)
                    state <= state_next;
            end
        endcase
    end
end

endmodule
