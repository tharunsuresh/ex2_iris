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

-- Interface to the SWIR Subsystem using an AvalonMM slave instead of
-- dedicated configuration and command ports


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.swir_types.all;

entity swir_subsystem_avalonmm is
port (
    clock               : in std_logic;
    reset_n             : in std_logic;

    avs_address         : in  std_logic_vector(7 downto 0);
    avs_read            : in  std_logic := '0';
    avs_readdata        : out std_logic_vector(31 downto 0);
    avs_write           : in  std_logic := '0';
    avs_writedata       : in  std_logic_vector(31 downto 0);
    avs_irq             : out std_logic;

    control             : out swir_control_t;
    
    pixel               : out swir_pixel_t;
    pxl_available       : out std_logic;
    
    sdi                 : out std_logic;
    sdo                 : in std_logic;
    sck                 : out std_logic;
    cnv                 : out std_logic;

    sensor_clock_even   : out std_logic;
    sensor_clock_odd    : out std_logic;
    sensor_reset_even   : out std_logic;
    sensor_reset_odd    : out std_logic;
    Cf_select1          : out std_logic;
    Cf_select2          : out std_logic;
    AD_sp_even          : in std_logic;
    AD_sp_odd           : in std_logic;
    AD_trig_even        : in std_logic;
    AD_trig_odd         : in std_logic
);
end entity swir_subsystem_avalonmm;


architecture rtl of swir_subsystem_avalonmm is

    component swir_controller is
    port (
        clock               : in std_logic;
        reset_n             : in std_logic := '0';

        avs_address         : in  std_logic_vector(7 downto 0);
        avs_read            : in  std_logic := '0';
        avs_readdata        : out std_logic_vector(31 downto 0);
        avs_write           : in  std_logic := '0';
        avs_writedata       : in  std_logic_vector(31 downto 0);
        avs_irq             : out std_logic;

        config              : out swir_config_t;
        start_config        : out std_logic;
        config_done         : in  std_logic;

        do_imaging          : out std_logic;
        imaging_done        : in  std_logic
    );
    end component swir_controller;

    component swir_subsystem is
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        
        config              : in swir_config_t;
        control             : out swir_control_t;
        start_config        : in std_logic;
        config_done         : out std_logic;
        
        do_imaging          : in std_logic;
        imaging_done        : out std_logic;

        pixel               : out swir_pixel_t;
        pxl_available       : out std_logic;

        sdi                 : out std_logic;
        sdo                 : in std_logic;
        sck                 : out std_logic;
        cnv                 : out std_logic;
        
        sensor_clock_even   : out std_logic;
        sensor_clock_odd    : out std_logic;
        sensor_reset_even   : out std_logic;
        sensor_reset_odd    : out std_logic;
        Cf_select1          : out std_logic;
        Cf_select2          : out std_logic;
        AD_sp_even          : in std_logic;
        AD_sp_odd           : in std_logic;
        AD_trig_even        : in std_logic;
        AD_trig_odd         : in std_logic
    );
    end component swir_subsystem;

    signal config               : swir_config_t;
    signal start_config         : std_logic;
    signal config_done          : std_logic;
    signal do_imaging           : std_logic;
    signal imaging_done         : std_logic;
    
begin

    swir_controller_cmp : swir_controller port map (
        clock => clock,
        reset_n => reset_n,
        avs_address => avs_address,
        avs_read => avs_read,
        avs_readdata => avs_readdata,
        avs_write => avs_write,
        avs_writedata => avs_writedata,
        avs_irq => avs_irq,

        config => config,
        start_config => start_config,
        config_done => config_done,

        do_imaging => do_imaging,
        imaging_done => imaging_done
    );

    swir_subsystem_cmp : swir_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        
        config => config,
        control => control,
        start_config => start_config,
        config_done => config_done,

        do_imaging => do_imaging,
        imaging_done => imaging_done,

        pixel => pixel,
        pxl_available => pxl_available,
        
        sdi => sdi,
        sdo => sdo,
        sck => sck,
        cnv => cnv,
        
        sensor_clock_even => sensor_clock_even,
        sensor_clock_odd => sensor_clock_odd,
        sensor_reset_even => sensor_reset_even,
        sensor_reset_odd => sensor_reset_odd,
        Cf_select1 => Cf_select1,
        Cf_select2 => Cf_select2,
        AD_sp_even => AD_sp_even,
        AD_sp_odd => AD_sp_odd,
        AD_trig_even => AD_trig_even,
        AD_trig_odd => AD_trig_odd
    );

end architecture rtl;
