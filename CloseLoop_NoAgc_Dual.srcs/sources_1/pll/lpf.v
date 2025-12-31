`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 11:10:55
// Design Name: 
// Module Name: lpf
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Loop filter with proportional-integral control
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lpf (
    input               clk,            // System clock (100MHz)
    input               processing,     // Processing status
    input               pd_done,        // Phase detector done signal
    input               rst_n,          // Asynchronous reset (active low)
    input signed [15:0] phase_err,      // Phase error from PD
    output reg signed [31:0]freq_word,  // Frequency control word to DCO
    output reg          lpf_done        // Processing complete flag
);

// Center frequency   F_out = (FCW / 2^N) * F_adc_clk
// localparam [31:0] CENTER_FREQ = 32'd90194313; // 21kHz in 32-bit fixed-point
// parameter  [31:0] CENTER_FREQ = 32'd85899346; // 20kHz in 32-bit fixed-point
parameter  [31:0] CENTER_FREQ = 32'd95580203; // 22254Hz in 32-bit fixed-point
//parameter  [31:0] CENTER_FREQ = 32'd95163590; // 22157Hz in 32-bit fixed-point

//Reference Phase Value(adc befer dac)
// Q2.14 signed format
reg signed [15:0] phase_err_d1;
// reg signed [31:0] phase_ctr_temp;

// State machine definition
localparam IDLE         = 3'b000;
localparam PROPORTIONAL = 3'b001;
localparam WAIT1        = 3'b011;
localparam INTEGRAL     = 3'b010;
localparam COMPARE      = 3'b110;
localparam ADD          = 3'b111;
localparam OUTPUT       = 3'b101;

reg [2:0] state = IDLE;


// Loop filter parameters (tunable)
// Kp = 100, Ki = 5 (fixed-point representation)
localparam signed [15:0] Kp = 16'd500;  // Proportional gain
localparam signed [15:0] Ki = 16'd300;    // Integral gain
reg signed [31:0] new_integrator;

// Internal signals

(* use_dsp = "yes" *) reg signed [31:0] proportional_temp;
reg signed [31:0] proportional;
(* use_dsp = "yes" *) reg signed [31:0] pre_integrator_temp;
reg signed [31:0] integrator, pre_integrator;
reg signed [31:0] temp_freq_word;

// State machine and processing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        phase_err_d1 <= 16'd0;
        // phase_ctr_temp <= 32'd0;
        proportional_temp <= 32'd0;
        proportional <= 32'd0;
        pre_integrator_temp <= 32'd0; 
        pre_integrator <= 32'd0; 
        integrator <= 32'd0;
        temp_freq_word <= CENTER_FREQ;
        freq_word <= CENTER_FREQ;
        lpf_done <= 0;
        new_integrator <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                lpf_done <= 0;
                if (pd_done && processing) begin
                    state <= PROPORTIONAL;
                    phase_err_d1 <= phase_err;
                end
            end
            
            PROPORTIONAL: begin
                // Calculate proportional term
                proportional_temp <= phase_err_d1 * Kp;
                pre_integrator_temp <= phase_err_d1 * Ki;
                state <= WAIT1;
            end

            WAIT1: begin
                proportional <= proportional_temp;
                pre_integrator <= (pre_integrator_temp>>>8);
                state <= INTEGRAL;
            end
            
            INTEGRAL: begin
                // Update integrator
                new_integrator <= integrator + pre_integrator;
                state <= COMPARE;
            end

            COMPARE: begin
                // Prevent integrator windup (limit range)
                if (new_integrator > $signed(32'h3FFFFFFF))
                    integrator <= $signed(32'h3FFFFFFF);
                else if (new_integrator < $signed(-32'h4000000))
                    integrator <= $signed(-32'h40000000);//16'h100
                else
                    integrator <= new_integrator;

                state <= ADD;
            end

            ADD: begin
                // Calculate frequency control word
                temp_freq_word <= CENTER_FREQ + proportional + integrator;    
                state <= OUTPUT;            
            end
            
            OUTPUT: begin                
                // Limit frequency range
                if (temp_freq_word > $signed(32'h7FFFFFFF))
                    freq_word <= $signed(32'h7FFFFFFF);
                else if (temp_freq_word < $signed(32'd0))
                    freq_word <= $signed(32'd0);
                else
                    freq_word <= temp_freq_word;
                
                lpf_done <= 1;
                state <= IDLE;
            end
        endcase
        
        // Reset state if processing is stopped
        if (!processing && state != IDLE) begin
            state <= IDLE;
            lpf_done <= 0;
        end
    end
end

endmodule