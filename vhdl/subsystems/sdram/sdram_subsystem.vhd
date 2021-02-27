----------------------------------------------------------------
-- Copyright 2020 University of Alberta

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.avalonmm;
use work.sdram;
use work.img_buffer_pkg.all;
use work.vnir;
use work.swir_types.all;
use work.fpga.timestamp_t;


entity sdram_subsystem is
    port (
        --Control signals
        clock               : in std_logic;
        reset_n             : in std_logic;

        --VNIR row signals
        vnir_row_available  : in vnir.row_type_t;
        vnir_num_rows       : in integer;
        vnir_row            : in vnir.row_t;
        
        --SWIR row signals
        swir_pxl_available  : in std_logic;
        swir_num_rows       : in integer;
        swir_pixel          : in swir_pixel_t;
        
        timestamp           : in timestamp_t;
        mpu_memory_change   : in sdram.address_block_t;
        config_in           : in sdram.config_to_sdram_t;
        start_config        : in std_logic;
        config_out          : out sdram.memory_state_t;
        config_done         : out std_logic;
        img_config_done     : out std_logic;
        
        sdram_busy          : out std_logic;
        sdram_error         : out sdram.error_t;
        
        sdram_avalon_out    : out avalonmm.from_master_t;
        sdram_avalon_in     : in avalonmm.to_master_t
    );
end entity sdram_subsystem;

architecture rtl of sdram_subsystem is

    --header_creator <==> command_creator
    signal vnir_header : sdram.header_t;
    signal swir_header : sdram.header_t;

    --imaging_buffer <==> command_creator
    signal row_frag     : row_fragment_t;
    signal next_row_req : std_logic;
    signal transmitting : std_logic;

    --imaging_buffer <==> memory_map
    signal next_row_type : sdram.row_type_t;

    --command_creator <==> memory_map
    signal address : sdram.address_t;

    --header_creator <==> memory_map
    signal img_config_done_i : std_logic;

begin
    imaging_buffer_component : entity work.imaging_buffer port map(
        clock               => clock,
        reset_n             => reset_n,
        vnir_row            => vnir_row,
        swir_pixel          => swir_pixel,
        fragment_out        => row_frag,
        fragment_type       => next_row_type,
        row_request         => next_row_req,
        transmitting        => transmitting,
        swir_pixel_ready    => swir_pxl_available,
        vnir_row_ready      => vnir_row_available
    );

    memory_map_component : entity work.memory_map port map(
        clock               => clock,
        reset_n             => reset_n,
        config              => config_in,
        memory_state        => config_out,
        start_config        => start_config,
        config_done         => config_done,
        img_config_done     => img_config_done_i,
        number_swir_rows    => swir_num_rows,
        number_vnir_rows    => vnir_num_rows,
        next_row_type       => next_row_type,
        next_row_req        => next_row_req,
        output_address      => address,
        sdram_error         => sdram_error
    );

    command_creator_component : entity work.command_creator port map(
        clock               => clock,
        reset_n             => reset_n,
        vnir_img_header     => vnir_header,
        swir_img_header     => swir_header,
        row_data            => row_frag,
        row_type            => next_row_type,
        address             => address,
        buffer_transmitting => transmitting,
        next_row_req        => next_row_req,
        sdram_busy          => sdram_busy,
        sdram_avalon_out    => sdram_avalon_out,
        sdram_avalon_in     => sdram_avalon_in
    );

    header_creator_component : entity work.header_creator port map(
        clock           => clock,
        reset_n         => reset_n,
        timestamp       => timestamp,
        swir_img_header => vnir_header,
        vnir_img_header => swir_header,
        vnir_rows       => vnir_num_rows,
        swir_rows       => swir_num_rows,
        img_config_done => img_config_done_i
    );

    img_config_done <= img_config_done_i;
end architecture;