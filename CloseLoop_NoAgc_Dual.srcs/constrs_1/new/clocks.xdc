create_clock -period 20.000 -name clk_50M -waveform {0.000 10.000} [get_ports clk_50M]

set_false_path -from [get_ports rst_n]


#set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins u_clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks -of_objects [get_pins u_clk_wiz_0/inst/mmcm_adv_inst/CLKOUT1]]

