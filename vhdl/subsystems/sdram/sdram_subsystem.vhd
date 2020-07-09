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

use work.avalonmm_types.all;
use work.sdram_types.all;
use work.vnir_types.all;
use work.swir_types.all;
use work.fpga_types.all;


entity sdram_subsystem is
    port (
        --Control signals
        clock               : in std_logic;
        reset_n             : in std_logic;

        --VNIR row signals
        vnir_rows_available : in std_logic;
        vnir_num_rows       : in integer;
        vnir_rows           : in vnir_rows_t;
        
        --SWIR row signals
        swir_row_available  : in std_logic;
        swir_num_rows       : in integer;
        swir_row            : in swir_row_t;
        
        timestamp           : in timestamp_t;
        mpu_memory_change   : in sdram_address_list_t;
        config_in           : in sdram_config_to_sdram_t;
        config_out          : out sdram_config_from_sdram_t;
        config_done         : out std_logic;
        
        sdram_busy          : out std_logic;
        sdram_error         : out stdram_error_t;
        
        sdram_avalon_out    : out avalonmm_rw_from_master_t;
        sdram_avalon_in     : in avalonmm_rw_to_master_t
    );
end entity sdram_subsystem;

architecture rtl of sdram_subsystem is

    component memory_map is
    port(
        
    )