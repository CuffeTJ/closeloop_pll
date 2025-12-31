`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 11:11:10
// Design Name: 
// Module Name: dco
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Digitally controlled oscillator with sine/cosine outputs
// 
// Dependencies: sine_lut.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module dco (
    input               clk,            // System clock (100MHz)
    input               processing,     // Processing status
    input               lpf_done,       // Loop filter done signal
    input               rst_n,          // Asynchronous reset (active low)
    input [31:0]        freq_word,      // Frequency control word from LPF
    output reg signed [15:0] dac_out,   // 12-bit DAC output
    output reg signed [15:0] dco_sin,   // Sine output for mixing
    output reg signed [15:0] dco_cos,   // Cosine output for mixing
    output reg          dco_done        // Processing complete flag
);


parameter SHIFT_DEGREE = 16'h8000;      // 180 degree offset (-32768~+32767 maps to -pi~+pi)
parameter DAC_SHIFT_BITS = 3'd3;        // DAC out right shift bits
// State machine definition
localparam IDLE         = 3'b000;
localparam PHASE_ACC    = 3'b001;
localparam PHASE_CAL    = 3'b011;
localparam LOOKUP       = 3'b010;
localparam OUTPUT       = 3'b110;

reg [2:0] state = IDLE;
reg lut_st;
wire lut_done;

// Phase accumulator (32-bit for fine frequency resolution)
reg [31:0] phase_acc = 0;

// Phase for sine/cosine lookup (16-bit)
reg [15:0] phase_sin, phase_cos, phase_shift;

// Sine/cosine values from lookup table
wire signed [15:0] sin_value, cos_value, shift_value;

// State machine and processing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        phase_acc <= 32'd0;
        phase_sin <= 16'd0;
        phase_cos <= 16'd0;
        phase_shift <= SHIFT_DEGREE;
        lut_st <= 1'b0;
        dac_out <= 16'd0;
        dco_sin <= 16'd0;
        dco_cos <= 16'd0;
        dco_done <= 0;
    end else begin
        case (state)
            IDLE: begin
                dco_done <= 0;
                if (lpf_done && processing) begin
                    state <= PHASE_ACC;
                end
            end
            
            PHASE_ACC: begin
                // Update phase accumulator
                phase_acc <= phase_acc + freq_word;
                state <= PHASE_CAL;
            end

            PHASE_CAL: begin
                // Calculate sine and cosine phases
                phase_sin <= phase_acc[31:16];                // Sine phase
                phase_cos <= phase_acc[31:16] + 16'h4000;     // Cosine phase (90 degree offset)
                phase_shift <= phase_acc[31:16] + SHIFT_DEGREE;
                
                lut_st <= 1'b1;
                state <= LOOKUP;
            end
            
            LOOKUP: begin
                lut_st <= 1'b0;
                // Wait one cycle for lookup table access
                if(lut_done == 1'b1) begin
                    state <= OUTPUT;
                end
            end
            
            OUTPUT: begin
                // Update outputs
                dco_sin <= sin_value;
                dco_cos <= cos_value;
                
                // Scale sine to 12-bit unsigned for DAC
                dac_out <= (shift_value >>> DAC_SHIFT_BITS);  // Shift and offset
                
                dco_done <= 1;
                state <= IDLE;
            end
        endcase
        
        // Reset state if processing is stopped
        if (!processing && state != IDLE) begin
            state <= IDLE;
            dco_done <= 0;
        end
    end
end

// Sine/cosine/shift lookup table
sine_lut  u_sine_lut (
    .clk                     ( clk           ),
    .lut_st                  ( lut_st        ),
    .phase_sin               ( phase_sin     ),
    .phase_cos               ( phase_cos     ),
    .phase_shift             ( phase_shift   ),

    .lut_done                ( lut_done      ),
    .sin_out                 ( sin_value     ),
    .cos_out                 ( cos_value     ),
    .shift_out               ( shift_value   )
);


endmodule