`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 11:10:28
// Design Name: 
// Module Name: pd
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Phase detector with CORDIC-based phase and amplitude calculation
// 
// Dependencies: cordic_vector.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module pd (
    input               clk,            // System clock (100MHz)
    input               clk_en_pulse,   // Pulse for triggering calculation
    input               processing,     // Processing status
    input               rst_n,          // Asynchronous reset (active low)
    input signed [15:0] adc_data,       // 16-bit ADC input
    input signed [15:0] dco_sin,        // DCO sine output
    input signed [15:0] dco_cos,        // DCO cosine output
    output reg signed [15:0] phase_err, // 16-bit phase error
    output reg signed [15:0] amplitude, // 16-bit amplitude
    output reg          pd_done         // Processing complete flag
);

parameter AMP_LIMIT = 16'd500;
// localparam PD_LPF_GAIN = 1.32;
// State machine definition
localparam IDLE         = 3'b000;
localparam INPUT_REG    = 3'b001;
localparam MIXING       = 3'b011;
localparam OUTPUT_REG   = 3'b010;
localparam FILTERING    = 3'b110;
localparam FILTERED     = 3'b111;
localparam CORDIC       = 3'b101;

reg [2:0] state = IDLE;

//INPUT_REG
reg signed [15:0] adc_data_d1, dco_sin_d1, dco_cos_d1;

// Quadrature mixing
(* use_dsp = "yes" *) reg signed [31:0] mix_i_temp, mix_q_temp;
reg signed [31:0] mix_i, mix_q;

// Low-pass filter (2nd-order IIR, fc=1kHz)
reg signed [31:0] lpf_i, lpf_q;

// CORDIC inputs and outputs
reg signed [15:0] cordic_x_in, cordic_y_in;
wire signed [15:0] cordic_phase_out;
wire [15:0] cordic_amp_out;
wire cordic_done;

// State machine and processing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        adc_data_d1 <= 16'd0;
        dco_sin_d1 <= 16'd0;
        dco_cos_d1 <= 16'd0;
        mix_i_temp <= 32'd0;
        mix_q_temp <= 32'd0;
        mix_i <= 32'd0;
        mix_q <= 32'd0;
        lpf_i <= 32'd0;
        lpf_q <= 32'd0;
        cordic_x_in <= 16'd0;
        cordic_y_in <= 16'd0;
        phase_err <= 16'd0;
        amplitude <= 16'd0;
        pd_done <= 0;
    end else begin
        case (state)
            IDLE: begin
                pd_done <= 0;
                if (clk_en_pulse) begin
                    state <= INPUT_REG;
                end
            end

            INPUT_REG: begin
                adc_data_d1 <= adc_data;
                dco_sin_d1 <= dco_sin;
                dco_cos_d1 <= dco_cos;
                state <= MIXING;
            end
            
            MIXING: begin
                // Quadrature mixing
                mix_i_temp <= adc_data_d1 * dco_sin_d1;    // I-channel mixing 
                mix_q_temp <= adc_data_d1 * dco_cos_d1;    // Q-channel mixing
                state <= OUTPUT_REG;
            end

            OUTPUT_REG: begin
                mix_i <= mix_i_temp;
                mix_q <= mix_q_temp;
                state <= FILTERING;
            end
            
            FILTERING: begin
                //lpf_iq = (1/128) * mix_iq + (127/128) * lpf_iq, fc = (1/128)*fs/2pi
                //lpf_iq = adc_data * 2^14
                lpf_i <= (mix_i >>> 7) + (lpf_i - (lpf_i >>> 7)); 
                lpf_q <= (mix_q >>> 7) + (lpf_q - (lpf_q >>> 7));
                state <= FILTERED;
            end
            
            FILTERED: begin
                // Prepare CORDIC inputs
                // cordic_x_in <= lpf_i[31:16];  // Take high 16 bits
                // cordic_y_in <= lpf_q[31:16];
                cordic_x_in <= {lpf_i[31], lpf_i[28:14]};  
                cordic_y_in <= {lpf_q[31], lpf_q[28:14]};
                
                state <= CORDIC;
            end
            
            CORDIC: begin
                if (cordic_done) begin
                    if(cordic_amp_out < AMP_LIMIT) begin
                        phase_err <= 16'd0;
                        amplitude <= 16'd0;
                    end
                    else begin
                        phase_err <= cordic_phase_out;
                        amplitude <= cordic_amp_out;
                    end
//                      phase_err <= 16'd0;
//                      amplitude <= 16'd0;                    
                    
                    pd_done <= 1;
                    state <= IDLE;
                end
            end
        endcase
        
        // Reset state if processing is stopped
        if (!processing && state != IDLE) begin
            state <= IDLE;
            pd_done <= 0;
        end
    end
end

// CORDIC phase/amplitude calculation (serial implementation)
cordic_vector cordic_pd (
    .clk(clk),
    .start(state == CORDIC && !cordic_done),
    .rst_n(rst_n),
    .x_in(cordic_x_in),
    .y_in(cordic_y_in),
    .phase_out(cordic_phase_out),
    .amp_out(cordic_amp_out),
    .done(cordic_done)
);

endmodule