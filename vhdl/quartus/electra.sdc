create_clock -name clock -period 20.000 [get_ports clock]
create_clock -name pll_ref_clock -period 20.000 [get_ports pll_ref_clock]
create_clock -name lvds_clock -period 4.166 [get_ports {vnir_lvds.clock}]
derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty

set vnir_sensor_clock "fpga_subsystem:fpga_cmp|interconnect:interconnect_cmp|interconnect_pll_0:pll_0|altera_pll:altera_pll_i|outclk_wire[0]"

set_output_delay -clock $vnir_sensor_clock -max 3 [get_ports {vnir_exposure_start vnir_frame_request}]
set_output_delay -clock $vnir_sensor_clock -min -2 [get_ports {vnir_exposure_start vnir_frame_request}]
set_false_path -from * -to [get_ports {vnir_sensor_power vnir_sensor_reset_n}]

set_input_delay -clock { clock } -max 3 [get_ports {vnir_spi_in.data}]
set_input_delay -clock { clock } -min 0 [get_ports {vnir_spi_in.data}]
set_output_delay -clock { clock } -max 3 [get_ports {vnir_spi_out.*}]
set_output_delay -clock { clock } -min -3 [get_ports {vnir_spi_out.*}]

set_input_delay -clock { lvds_clock } -max 1 [get_ports vnir_lvds.data*]
set_input_delay -clock { lvds_clock } -min 0 [get_ports vnir_lvds.data*]

set_false_path -from [get_registers {reset_n}] -to *
set_false_path -from * -through [get_nets {fpga_cmp|subsystem_reset_n}] -to *
