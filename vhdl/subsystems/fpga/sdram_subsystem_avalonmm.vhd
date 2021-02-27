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

-- Interface to the SDRAM Subsystem using an AvalonMM slave instead of
-- dedicated configuration and command ports


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.spi_types.all;
use work.vnir;
use work.swir_types.all;
use work.sdram;
use work.fpga.timestamp_t;
use work.avalonmm;

entity sdram_subsystem_avalonmm is
port (
    clock               : in std_logic;
    reset_n             : in std_logic;

    avs_address         : in  std_logic_vector(7 downto 0);
    avs_read            : in  std_logic := '0';
    avs_readdata        : out std_logic_vector(31 downto 0);
    avs_write           : in  std_logic := '0';
    avs_writedata       : in  std_logic_vector(31 downto 0);
    avs_irq             : out std_logic;

    sdram_avalon_out    : out avalonmm.from_master_t;
    sdram_avalon_in     : in avalonmm.to_master_t;

    vnir_row_available  : in vnir.row_type_t;
    vnir_row            : in vnir.row_t;
    swir_pxl_available  : in std_logic;
    swir_pixel          : in swir_pixel_t
);
end entity sdram_subsystem_avalonmm;


architecture rtl of sdram_subsystem_avalonmm is

    component sdram_controller is
    port (
        clock               : in std_logic;
        reset_n             : in std_logic := '0';

        avs_address         : in  std_logic_vector(7 downto 0);
        avs_read            : in  std_logic := '0';
        avs_readdata        : out std_logic_vector(31 downto 0);
        avs_write           : in  std_logic := '0';
        avs_writedata       : in  std_logic_vector(31 downto 0);
        avs_irq             : out std_logic;

        swir_num_rows       : out integer;
        vnir_num_rows       : out integer;

        timestamp           : out timestamp_t;
        mpu_memory_change   : out sdram.address_block_t;
        config_to_sdram     : out sdram.config_to_sdram_t;
        start_config        : out std_logic;
        config_from_sdram   : in  sdram.memory_state_t;
        config_done         : in  std_logic;
        img_config_done     : in  std_logic;

        sdram_busy          : in std_logic;
        sdram_error         : in sdram.error_t
    );
    end component sdram_controller;

    component sdram_subsystem is
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;

        vnir_row_available  : in vnir.row_type_t;
        vnir_num_rows       : in integer;
        vnir_row            : in vnir.row_t;
        
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
    end component sdram_subsystem;

    signal swir_num_rows        : integer;
    signal vnir_num_rows        : integer;
    signal timestamp            : timestamp_t;
    signal mpu_memory_change    : sdram.address_block_t;
    signal config_to_sdram      : sdram.config_to_sdram_t;
    signal start_config         : std_logic;
    signal config_from_sdram    : sdram.memory_state_t;
    signal config_done          : std_logic;
    signal img_config_done      : std_logic;
    signal sdram_busy           : std_logic;
    signal sdram_error          : sdram.error_t;

begin

    sdram_controller_cmp : sdram_controller port map (
        clock => clock,
        reset_n => reset_n,
        avs_address => avs_address,
        avs_read => avs_read,
        avs_readdata => avs_readdata,
        avs_write => avs_write,
        avs_writedata => avs_writedata,
        avs_irq => avs_irq,

        swir_num_rows => swir_num_rows,
        vnir_num_rows => vnir_num_rows,
        
        timestamp => timestamp,
        mpu_memory_change => mpu_memory_change,
        config_to_sdram => config_to_sdram,
        start_config => start_config,
        config_from_sdram => config_from_sdram,
        config_done => config_done,
        img_config_done => img_config_done,
        
        sdram_busy => sdram_busy,
        sdram_error => sdram_error
    );

    sdram_subsystem_cmp : sdram_subsystem port map (
        clock => clock,
        reset_n => reset_n,

        vnir_row_available => vnir_row_available,
        vnir_num_rows => vnir_num_rows,
        vnir_row => vnir_row,
        
        swir_pxl_available => swir_pxl_available,
        swir_num_rows => swir_num_rows,
        swir_pixel => swir_pixel,
        
        timestamp => timestamp,
        mpu_memory_change => mpu_memory_change,
        config_in => config_to_sdram,
        start_config => start_config,
        config_out => config_from_sdram,
        config_done => config_done,
        img_config_done => img_config_done,
        
        sdram_busy => sdram_busy,
        sdram_error => sdram_error,
        
        sdram_avalon_out => sdram_avalon_out,
        sdram_avalon_in => sdram_avalon_in
    );

end architecture rtl;
