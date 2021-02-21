quit -sim
# vdel -all           # deletes work library
# vlib work           # creates work folder
# vmap work work      # map logical (modelsim) libraries to the physical library (folder)

# add & compile packages
vcom -2002 -explicit ../util/types.vhd
vcom -2002 -explicit ../util/pulse_genenerator.vhd
vcom -2002 -explicit ../subsystems/swir/swir_types.vhd
vcom -2002 -explicit ../subsystems/fpga/fpga_types.vhd
vcom -2008 -explicit ../subsystems/vnir/base/vnir_base_pkg.vhd
vcom -2002 -explicit ../subsystems/vnir/base/sensor_configurer/sensor_configurer_pkg.vhd
vcom -2002 -explicit ../subsystems/vnir/base/row_collector/row_collector_pkg.vhd
vcom -2008 -explicit ../subsystems/vnir/base/lvds_decoder/lvds_decoder_pkg.vhd
vcom -2002 -explicit ../subsystems/vnir/base/frame_requester/frame_requester_pkg.vhd
vcom -2008 -explicit ../subsystems/vnir/vnir_pkg.vhd
vcom -2002 -explicit ../subsystems/sdram/sdram_types.vhd
vcom -2008 -explicit {../subsystems/sdram/Imaging Buffer/imaging_buffer_pkg.vhd}
vcom -2008 -explicit {../subsystems/sdram/Command Creator/avalonmm_pkg.vhd}

# Imaging buffer files
vcom -2002 -explicit {../subsystems/sdram/Imaging Buffer/IP/VNIR_ROW_FIFO.vhd}
vcom -2002 -explicit {../subsystems/sdram/Imaging Buffer/IP/SWIR_Row_FIFO.vhd}
vcom -2008 -explicit {../subsystems/sdram/Imaging Buffer/imaging_buffer.vhd}
vcom -2008 -explicit {../subsystems/sdram/Imaging Buffer/fifo_row_encoder.vhd}

# Memory map files
# vcom -2002 -explicit {../subsystems/sdram/Memory Map/address_counter.vhd}
# vcom -2002 -explicit {../subsystems/sdram/Memory Map/memory_map.vhd}
# vcom -2002 -explicit {../subsystems/sdram/Memory Map/partition_register.vhd}

# Testbenches
vcom -2008 -explicit {../subsystems/sdram/Imaging Buffer/fifo_row_encoder_tb.vhd}
vcom -2002 -explicit ../subsystems/sdram/tests/imaging_buffer_tb.vhd
# vcom -2002 -explicit ../subsystems/sdram/tests/memory_map_tb.vhd

vsim -gui work.imaging_buffer_tb

add wave -unsigned -position end sim:/imaging_buffer_tb/vnir_row
# add wave -position end sim:/imaging_buffer_tb/*
add wave -position end sim:/imaging_buffer_tb/imaging_buffer/*

run 600 ns
wave zoom full
