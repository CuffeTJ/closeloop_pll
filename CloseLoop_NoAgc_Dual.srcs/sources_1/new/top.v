`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/15 14:19:06
// Design Name: 
// Module Name: top
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


module top(
input clk_50M,
input rst_n,

//ADC
output adc_cnv_1,
output adc_sck_1,
output adc_sdi_1,
input  adc_sdo_1,

output adc_cnv_2,
output adc_sck_2,
output adc_sdi_2,
input  adc_sdo_2,

//DAC
output dac_cs_n_1,
output dac_sclk_1,
output dac_sdin_1,
//output dac_busy_1

output dac_cs_n_2,
output dac_sclk_2,
output dac_sdin_2,
// output dac_busy_2

output tx
    );

wire cic_done;
wire [31:0] f1, f2;

clk_wiz_0 u_clk_wiz_0
(
    // Clock out ports
    .clk_100M(clk_100M),     // output clk_100M
    .clk_200M(),     // output clk_200M
    // Status and control signals
    .resetn(rst_n), // input resetn
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(clk_50M)      // input clk_in1
);

// Center frequency   F_out = (FCW / 2^N) * F_adc_clk
// 32'd4295 for 1Hz
// 32'd90194313;  21kHz in 32-bit fixed-point
// 32'd85899346;  20kHz in 32-bit fixed-point
// 32'd95567317;  22251Hz in 32-bit fixed-point
// 32'd95580203;  22254Hz in 32-bit fixed-point
// 32'd95163590;  22157Hz in 32-bit fixed-point
// 32'd95159295;  22156Hz in 32-bit fixed-point
// 32'd95150705;  22154Hz in 32-bit fixed-point
parameter FREQ_22250p6              = 32'd95565599;
parameter FREQ_22250p7              = 32'd95566028;
parameter FREQ_22250p8              = 32'd95566458;
parameter FREQ_22251                = 32'd95567317;
parameter FREQ_22254                = 32'd95580203;

parameter FREQ_22152p6              = 32'd95144692;
parameter FREQ_22152p7              = 32'd95145122;
parameter FREQ_22154                = 32'd95150705;
parameter FREQ_22156                = 32'd95159295;
parameter FREQ_22157                = 32'd95163590;

parameter PLL_LPF_CENTER_FREQ       = 32'd95580203; // 22254Hz in 32-bit fixed-point
parameter PLL_DCO_SHIFT_DEGREE      = 16'h8000;     // 180 degree offset(-32768~+32767 maps to -pi~+pi)
parameter PLL_DCO_DAC_SHIFT_BITS    = 3'd3;         // DAC out right shift bits
parameter PLL_PD_AMP_LIMIT          = 16'd100;      // PD_LPF_GAIN = 1.32;  pd_amp = adc_amp * PD_LPF_GAIN * CORDIC_GAIN   

multi_port   #(
    .PLL_LPF_CENTER_FREQ(FREQ_22250p7),
    .PLL_DCO_SHIFT_DEGREE(PLL_DCO_SHIFT_DEGREE),
    .PLL_DCO_DAC_SHIFT_BITS(PLL_DCO_DAC_SHIFT_BITS),
    .PLL_PD_AMP_LIMIT(PLL_PD_AMP_LIMIT)
)u_multi_port_1 (
    .clk_100M                ( clk_100M   ),
    .rst_n                   ( rst_n      ),
    .adc_sdo                 ( adc_sdo_1       ),

    .adc_cnv                 ( adc_cnv_1    ),
    .adc_sck                 ( adc_sck_1    ),
    .adc_sdi                 ( adc_sdi_1    ),
    .dac_cs_n                ( dac_cs_n_1   ),
    .dac_sclk                ( dac_sclk_1   ),
    .dac_sdin                ( dac_sdin_1   ),

    .cic_done               ( cic_done ),
    .fre_w                  (f1)
);

multi_port  #(
    .PLL_LPF_CENTER_FREQ(FREQ_22152p7),
    .PLL_DCO_SHIFT_DEGREE(PLL_DCO_SHIFT_DEGREE),
    .PLL_DCO_DAC_SHIFT_BITS(PLL_DCO_DAC_SHIFT_BITS),
    .PLL_PD_AMP_LIMIT(PLL_PD_AMP_LIMIT)
)u_multi_port_2 (
    .clk_100M                ( clk_100M   ),
    .rst_n                   ( rst_n      ),
    .adc_sdo                 ( adc_sdo_2  ),

    .adc_cnv                 ( adc_cnv_2    ),
    .adc_sck                 ( adc_sck_2    ),
    .adc_sdi                 ( adc_sdi_2    ),
    .dac_cs_n                ( dac_cs_n_2   ),
    .dac_sclk                ( dac_sclk_2   ),
    .dac_sdin                ( dac_sdin_2   ),

    .cic_done               ( ),
    .fre_w                  (f2)
);

uart_tx #(
    .BAUD_RATE ( 'd256000 ),
    .NUM_BYTE  ( 'd12     ))
 u_uart_tx (
    .clk_fs                  ( clk_100M     ),
    .rst_n                   ( rst_n        ),
    .data_valid              ( cic_done   ),
    .dout_a                  ( f1       ),
    .dout_b                  ( f2       ),

    .tx                      ( tx           )
);

endmodule
