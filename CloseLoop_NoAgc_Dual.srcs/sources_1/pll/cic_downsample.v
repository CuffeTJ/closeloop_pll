`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/15 13:32:15
// Design Name: 
// Module Name: cic_downsample
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


module cic_downsample (
    input               clk_100m,       // 100MHz系统时钟
    input               rst_n,          // 异步复位信号
    input               data_valid,     // 数据有效信号
    input  [31:0]       data_in,        // 32位输入数据
    output reg          cic_done,       // 降采样完成信号
    output reg [31:0]   data_out        // 降采样输出数据
);

// 参数定义
parameter INTEGRATOR_WIDTH = 48;        // 积分器位宽，防止溢出
parameter DECIMATION_RATIO = 1000;      // 降采样率 1MHz->1kHz

// 内部信号定义
reg [31:0] data_in_reg;                 // 输入数据寄存器
reg data_valid_d1, data_valid_d2;       // 数据有效信号延迟
wire data_valid_rise;                   // 数据有效上升沿

// 计数器
reg [9:0] sample_count;                 // 采样计数器 (0-999)
reg [9:0] decimation_count;             // 降采样计数器

// CIC滤波器寄存器
reg [INTEGRATOR_WIDTH-1:0] integrator;  // 积分器
reg [INTEGRATOR_WIDTH-1:0] comb_d1;     // 梳状器延迟1
reg [INTEGRATOR_WIDTH-1:0] comb_d2;     // 梳状器延迟2

// 数据有效上升沿检测
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        data_valid_d1 <= 1'b0;
        data_valid_d2 <= 1'b0;
    end else begin
        data_valid_d1 <= data_valid;
        data_valid_d2 <= data_valid_d1;
    end
end

assign data_valid_rise = data_valid_d1 & ~data_valid_d2;

// 输入数据锁存
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        data_in_reg <= 32'b0;
    end else if (data_valid_rise) begin
        data_in_reg <= data_in;
    end
end

// 采样计数器
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        sample_count <= 10'b0;
    end else if (data_valid_rise) begin
        if (sample_count == 10'd99) begin
            sample_count <= 10'b0;
        end else begin
            sample_count <= sample_count + 1'b1;
        end
    end
end

// 积分器阶段 (工作在1MHz)
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        integrator <= {INTEGRATOR_WIDTH{1'b0}};
    end else if (data_valid_rise) begin
        integrator <= integrator + {{(INTEGRATOR_WIDTH-32){data_in_reg[31]}}, data_in_reg};
    end
end

// 降采样计数器
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        decimation_count <= 10'b0;
    end else if (data_valid_rise) begin
        if (decimation_count == DECIMATION_RATIO - 1) begin
            decimation_count <= 10'b0;
        end else begin
            decimation_count <= decimation_count + 1'b1;
        end
    end
end

// 梳状器阶段 (工作在1kHz)
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        comb_d1 <= {INTEGRATOR_WIDTH{1'b0}};
        comb_d2 <= {INTEGRATOR_WIDTH{1'b0}};
        data_out <= 32'b0;
        cic_done <= 1'b0;
    end else if (data_valid_rise && (decimation_count == DECIMATION_RATIO - 1)) begin
        // 更新梳状器延迟
        comb_d1 <= integrator;
        comb_d2 <= comb_d1;
        
        // 计算输出: y[n] = x[n] - 2*x[n-1] + x[n-2]
        // 这里简化为单级梳状器: y[n] = x[n] - x[n-1]
        data_out <= (integrator - comb_d1) >> 10;  // 右移10位进行增益调整
        
        // 产生完成脉冲
        cic_done <= 1'b1;
    end else begin
        cic_done <= 1'b0;
    end
end

// 添加输出数据有效信号
reg output_valid;
always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        output_valid <= 1'b0;
    end else begin
        output_valid <= cic_done;
    end
end

endmodule
