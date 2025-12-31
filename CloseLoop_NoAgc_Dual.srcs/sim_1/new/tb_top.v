//~ `New testbench
`timescale  1ns / 1ps

module tb_top;

// io_top Parameters
parameter PERIOD  = 20;

// top Inputs
reg   clk_50M    = 0;
reg   rst_n      = 0;
wire  adc_sdo_1 ;

// top Outputs
wire  adc_cnv_1;
wire  adc_sck_1;
wire  adc_sdi_1;
wire  dac_cs_n_1;
wire  dac_sclk_1;
wire  dac_sdin_1;



reg [15:0] data_in_cnt   = 0 ; 
reg [15:0] i    = 0;
reg [15:0] j    = 0;
wire [15:0]  temp_in;

initial
begin
    forever #(PERIOD/2)  clk_50M=~clk_50M;
end

initial
begin
    #(PERIOD*2) rst_n  =  1;
end

always @(posedge adc_cnv_1) begin
    if(!rst_n)  data_in_cnt <= 16'd0;
    else data_in_cnt <= data_in_cnt + 1'd1;
end

localparam N = 5000;
reg signed [15:0] sin_wave [0:N-1];
initial begin
    $readmemh("sine_wave.mem", sin_wave);
end

always @(negedge adc_sck_1 or negedge rst_n or posedge adc_cnv_1) begin
    if(!rst_n)   i <= 0;
    else if(adc_cnv_1) i <= 0;
    else if(i == 15) i <= 0;
    else     i <= i+1;
end

always @(negedge adc_sck_1) begin
    if(!rst_n)   j <= 0;
    else if(i == 15) j <= j+1;
end

// assign adc_sdo_1 = data_in_cnt[15-i];
assign adc_sdo_1 = sin_wave[j][15-i];
assign temp_in = sin_wave[j];


top  u_top (
    .clk_50M                 ( clk_50M      ),
    .rst_n                   ( rst_n        ),
    .adc_sdo_1               ( adc_sdo_1    ),

    .adc_cnv_1               ( adc_cnv_1    ),
    .adc_sck_1               ( adc_sck_1    ),
    .adc_sdi_1               ( adc_sdi_1    ),
    .dac_cs_n_1              ( dac_cs_n_1   ),
    .dac_sclk_1              ( dac_sclk_1   ),
    .dac_sdin_1              ( dac_sdin_1   )
);

endmodule