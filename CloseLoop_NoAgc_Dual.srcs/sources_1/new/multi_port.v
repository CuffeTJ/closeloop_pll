`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/15 20:16:46
// Design Name: 
// Module Name: multi_port
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


module multi_port(
input clk_100M,
input rst_n,

//ADC
output adc_cnv,
output adc_sck,
output adc_sdi,
input  adc_sdo,

//DAC
output dac_cs_n,
output dac_sclk,
output dac_sdin,
//output dac_busy

output cic_done,
output [31:0] fre_w
    );

// Center frequency   F_out = (FCW / 2^N) * F_adc_clk
// 32'd90194313;  21kHz in 32-bit fixed-point
// 32'd85899346;  20kHz in 32-bit fixed-point
// 32'd95580203;  22254Hz in 32-bit fixed-point
// 32'd95163590;  22157Hz in 32-bit fixed-point
parameter PLL_LPF_CENTER_FREQ       = 32'd95580203; // 22254Hz in 32-bit fixed-point   
parameter PLL_DCO_SHIFT_DEGREE      = 16'h8000;     // 180 degree offset(-32768~+32767 maps to -pi~+pi)
parameter PLL_DCO_DAC_SHIFT_BITS    = 3'd3;         // DAC out right shift bits
parameter PLL_PD_AMP_LIMIT          = 16'd500;      // PD_LPF_GAIN = 1.32;

wire  [15:0]  conversion_data;
wire  data_ready;
ad4001_driver_single #(
    .SAMPLING_RATE_SPS ( 1_000_000 ))
 u_ad4001_driver_single (
    .clk_fs                  ( clk_100M        ),
    .reset_n                 ( rst_n           ),

    .adc_sdo                 ( adc_sdo           ),
    .adc_cnv                 ( adc_cnv           ),
    .adc_sck                 ( adc_sck           ),

    .conversion_data         ( conversion_data   ),
    .data_ready              ( data_ready        )
);


// adpll_top Outputs
wire  clk_dac;
wire signed [15:0]  data_pll_out;
wire signed [15:0]  amplitude_out;

adpll_top  #(
    .PD_AMP_LIMIT(PLL_PD_AMP_LIMIT),
    .LPF_CENTER_FREQ(PLL_LPF_CENTER_FREQ),
    .DCO_SHIFT_DEGREE(PLL_DCO_SHIFT_DEGREE),
    .DCO_DAC_SHIFT_BITS(PLL_DCO_DAC_SHIFT_BITS)
)u_adpll_top (
    .clk_fs                  ( clk_100M          ),
    .clk_adc                 ( data_ready        ),
    .rst_n                   ( rst_n             ),
    .data_adc_in             ( conversion_data   ),

    .clk_dac                 ( clk_dac          ),
    .data_out                ( data_pll_out     ),
    .amplitude_out           ( amplitude_out    ),

    .cic_done                ( cic_done         ),
    .fre_w                   ( fre_w            )
);




ad5543_driver_seq #(
    .CLK_FREQ  ( 100_000_000 ),
    .SCLK_FREQ ( 50_000_000  ))
 u_ad5543_driver_seq (
    .clk                     ( clk_100M         ),
    .reset_n                 ( rst_n            ),
    .data_in                 ( {~data_pll_out[15], data_pll_out[14:0]}    ),
    .start_transfer          ( clk_dac    ),

    .dac_cs_n                ( dac_cs_n         ),
    .dac_sclk                ( dac_sclk         ),
    .dac_sdin                ( dac_sdin         ),
    .busy                    (              )
);

assign adc_sdi = 1'b1;

endmodule
