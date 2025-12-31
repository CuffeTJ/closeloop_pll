`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/12/12 14:32:45
// Design Name: 
// Module Name: uart_tx
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


module uart_tx(
input clk_fs,
input rst_n,
input data_valid,
input [31:0] dout_a,
input [31:0] dout_b,

output reg tx
    );

parameter BAUD_RATE = 'd256000;
parameter NUM_BYTE = 'd12; //数据有8个字节，起始字节4个，共12个字节

localparam CNT_FLGA = 25_000_000/BAUD_RATE - 1;

reg[9:0]    data_reg[NUM_BYTE-1:0];//1起始，8数据，0校验，1停止
reg[10:0]   cnt_baud;
reg[4:0]    cnt_bit;
reg[7:0]    cnt_byte;


reg [2:0] state;
reg tx_en;


wire[63:0] dout = {dout_a[31:0], dout_b[31:0]};


localparam [2:0] IDLE       = 3'b000,
                 TX         = 3'b001;

reg data_valid_d1;
wire valid_flag = data_valid&(!data_valid_d1);
always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) data_valid_d1 <= 1'b0;
    else data_valid_d1 <= data_valid;
end

always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n) begin:loop_rst
        integer i;
        for(i=0;i<NUM_BYTE;i=i+1) begin
            if(i<4) data_reg[i] <= 10'b1_1111_1111_0;
            else data_reg[i] <= 10'b1_1111_1111_1;
        end
        tx_en <= 1'b0;
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                if(valid_flag) begin:loop_idle
                    integer i;
                    for(i=4;i<NUM_BYTE;i=i+1) begin
                        data_reg[i] = {1'b1, dout[(95-8*i)-:8], 1'b0};
                    end
                    tx_en <= 1'b1;
                    state <= TX;
                end
            end
            TX: begin
                if((cnt_baud == CNT_FLGA)&(cnt_bit == 4'd9)&(cnt_byte == NUM_BYTE-1)) begin
                    tx_en <= 1'b0;
                    state <= IDLE;
                end
            end
        endcase
    end
end

always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)
        cnt_baud <= 'b0;
    else if(tx_en == 1'b1) begin
        if(cnt_baud == 100_000_000/BAUD_RATE - 1) 
            cnt_baud <= 'b0;
        else
            cnt_baud <= cnt_baud +1'b1;
    end
    else 
        cnt_baud <= 'b0;
end

always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)
        cnt_bit <= 4'b0;
    else if(cnt_baud == CNT_FLGA) begin
        if(cnt_bit == 4'd9)    cnt_bit <= 4'b0;
        else    cnt_bit <= cnt_bit + 1'b1;
    end
end

always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)  cnt_byte <= 'b0;
    else if(!tx_en)     cnt_byte <= 'b0;
    else if(cnt_baud == CNT_FLGA) begin
        if((cnt_byte == NUM_BYTE - 1)&(cnt_bit == 4'd9))   cnt_byte <= 8'd0;
        else if(cnt_bit == 4'd9)    cnt_byte <= cnt_byte + 1'b1;
        else cnt_byte <= cnt_byte;
    end
end


always @(posedge clk_fs or negedge rst_n) begin
    if(!rst_n)
        tx <= 1'b1;
    else if(cnt_baud == CNT_FLGA) 
        tx <= data_reg[cnt_byte][cnt_bit];
    else 
        tx <= tx;
end

endmodule
