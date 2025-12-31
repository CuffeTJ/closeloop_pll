`timescale 1ns / 1ps
module ad5543_driver_seq #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer SCLK_FREQ = 50_000_000
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire [15:0] data_in,
    input  wire        start_transfer,
    output reg         dac_cs_n,
    output reg         dac_sclk,
    output reg         dac_sdin,
    output reg         busy
);
    localparam SCLK_PERIOD_CYCLES = (CLK_FREQ + (SCLK_FREQ / 2)) / SCLK_FREQ;
    localparam SCLK_TOGGLE_POINT  = SCLK_PERIOD_CYCLES / 2;
    localparam [1:0] IDLE  = 2'b00, START = 2'b01, SHIFT = 2'b10, STOP  = 2'b11;
    reg [1:0]  state;
    reg [15:0] data_reg;
    reg [4:0]  bit_count;
    reg [$clog2(SCLK_PERIOD_CYCLES)-1:0] sclk_div_count;
    reg start_transfer1;
    reg start_transfer2;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            start_transfer1 <= 1'b0;
            start_transfer2 <= 1'b0;
        end else begin
        start_transfer1 <= start_transfer;
        start_transfer2 <= start_transfer1;
        end
    end
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state          <= IDLE;
            dac_cs_n       <= 1'b1;
            dac_sclk       <= 1'b0;
            dac_sdin       <= 1'b0;
            busy           <= 1'b0;
            data_reg       <= 16'd0;
            bit_count      <= 0;
            sclk_div_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    dac_cs_n <= 1'b1;
                    dac_sclk <= 1'b0; // MODIFIED: SCLK idles low
                    busy     <= 1'b0;
                    dac_sdin <= 1'b0;
                    sclk_div_count <= 0;
                    if (start_transfer2 == 1'b1 && start_transfer1 == 1'b0) begin
                        data_reg  <= data_in;
                        bit_count <= 15;
                        state     <= START;
                    end
                end
                START: begin
                    busy     <= 1'b1;
                    dac_cs_n <= 1'b0;
                    dac_sclk <= 1'b0;
                    dac_sdin <= data_reg[15];
                    state    <= SHIFT;
                end
                SHIFT: begin
                    dac_cs_n <= 1'b0;
                    busy     <= 1'b1;
                    dac_sdin <= data_reg[15];
                    if (sclk_div_count < SCLK_TOGGLE_POINT) begin
                        dac_sclk <= 1'b0;
                    end else begin
                        dac_sclk <= 1'b1;
                    end
                    if (sclk_div_count == SCLK_PERIOD_CYCLES - 1) begin
                        sclk_div_count <= 0;
                        data_reg  <= data_reg << 1;
                        bit_count <= bit_count - 1;
                        if (bit_count == 0) begin
                            state <= STOP;
                        end
                    end else begin
                        sclk_div_count <= sclk_div_count + 1;
                    end
                end
                STOP: begin
                    dac_cs_n <= 1'b1;
                    dac_sclk <= 1'b0; // MODIFIED: SCLK returns to idle low
                    busy     <= 1'b1;
                    state    <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule