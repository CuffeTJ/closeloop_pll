`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/12 11:11:23
// Design Name: 
// Module Name: adpll_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: ADPLL top module with phase detector, loop filter and DCO
// 
// Dependencies: pd.v, lpf.v, dco.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module adpll_top (
    input                   clk_fs,         // System clock (100MHz)
    input                   clk_adc,        // ADC sampling clock (1MHz)
    input                   rst_n,          // Asynchronous reset (active low)
    input signed [15:0]     data_adc_in,    // ADC input data (16-bit signed)
    output                  clk_dac,        // DAC clock output (1MHz)
    output signed [15:0]    data_out,       // DAC output data (12-bit)
    output signed [15:0]    amplitude_out,   // Signal amplitude output (for monitoring)

    output cic_done,
    output [31:0]      fre_w     
);

// Center frequency   F_out = (FCW / 2^N) * F_adc_clk
// 32'd90194313;  21kHz in 32-bit fixed-point
// 32'd85899346;  20kHz in 32-bit fixed-point
// 32'd95580203;  22254Hz in 32-bit fixed-point
// 32'd95163590;  22157Hz in 32-bit fixed-point
parameter LPF_CENTER_FREQ       = 32'd95580203; // 22254Hz in 32-bit fixed-point
parameter DCO_SHIFT_DEGREE      = 16'h8000;     // 180 degree offset(-32768~+32767 maps to -pi~+pi)
parameter DCO_DAC_SHIFT_BITS    = 3'd3;         // DAC out right shift bits
parameter PD_AMP_LIMIT          = 16'd500;      // PD_LPF_GAIN = 1.32;
// Clock domain synchronization
reg clk_en = 0;
reg clk_en_d1 = 0;
wire clk_en_pulse;

always @(posedge clk_fs or negedge rst_n) begin
    if (!rst_n) begin
        clk_en <= 0;
        clk_en_d1 <= 0;
    end else begin
        clk_en <= clk_adc; // Generate 1MHz enable signal
        clk_en_d1 <= clk_en;
    end
end

// Pulse detection for triggering calculations
assign clk_en_pulse = clk_en && !clk_en_d1;

// Processing status flag
reg processing = 0;
reg processing_done = 1;

// Signal connections
wire signed [15:0] phase_err;      // Phase error from PD
wire signed [15:0] amplitude;      // Signal amplitude from PD
wire [31:0] freq_word;             // Frequency control word from LPF
wire signed [15:0] dco_sin, dco_cos; // Quadrature outputs from DCO
wire pd_done, lpf_done, dco_done;  // Module completion signals


// Processing control
always @(posedge clk_fs or negedge rst_n) begin
    if (!rst_n) begin
        processing <= 0;
        processing_done <= 1;
    end else begin
        if (clk_en_pulse) begin
            processing <= 1;       // Start processing
            processing_done <= 0;  // Clear done flag
        end else if (processing && dco_done) begin
            processing <= 0;       // End processing
            processing_done <= 1;  // Set done flag
        end
    end
end


// Module instantiations
pd #(
    .AMP_LIMIT(PD_AMP_LIMIT)
)pd_inst (
    .clk(clk_fs),
    .clk_en_pulse(clk_en_pulse),
    .processing(processing),
    .rst_n(rst_n),
    .adc_data(data_adc_in),
    .dco_sin(dco_sin),
    .dco_cos(dco_cos),
    .phase_err(phase_err),
    .amplitude(amplitude),
    .pd_done(pd_done)
);

lpf #(
    .CENTER_FREQ(LPF_CENTER_FREQ)
)lpf_inst (
    .clk(clk_fs),
    .processing(processing),
    .pd_done(pd_done),
    .rst_n(rst_n),
    .phase_err(phase_err),
    .freq_word(freq_word),
    .lpf_done(lpf_done)
);

dco #(
    .SHIFT_DEGREE(DCO_SHIFT_DEGREE),
    .DAC_SHIFT_BITS(DCO_DAC_SHIFT_BITS)
)dco_inst (
    .clk(clk_fs),
    .processing(processing),
    .lpf_done(lpf_done),
    .rst_n(rst_n),
    .freq_word(freq_word),
//    .freq_word(32'd90194313),
    .dac_out(data_out),
    .dco_sin(dco_sin),
    .dco_cos(dco_cos),
    .dco_done(dco_done)
);

// cic_downsample Parameters
parameter INTEGRATOR_WIDTH  = 48  ;
parameter DECIMATION_RATIO  = 1000;


cic_downsample #(
    .INTEGRATOR_WIDTH ( 48   ),
    .DECIMATION_RATIO ( 1000 ))
 u_cic_downsample (
    .clk_100m                ( clk_fs     ),
    .rst_n                   ( rst_n        ),
    .data_valid              ( lpf_done   ),
    .data_in                 ( freq_word      ),

    .cic_done                ( cic_done     ),
    .data_out                ( fre_w        )
);

// DAC clock output (synchronized with 1MHz)
assign clk_dac = processing_done;
assign amplitude_out = amplitude;
assign data_sin = dco_sin;

endmodule