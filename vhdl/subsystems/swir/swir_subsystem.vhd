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

use work.swir_types.all;


entity swir_subsystem is
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

        -- Signals to/from ADC
        sdi                 : out std_logic;
        sdo                 : in std_logic;
        sck                 : out std_logic;
        cnv                 : out std_logic;
        
        -- Signals to/from SWIR sensor
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
end entity swir_subsystem;


architecture rtl of swir_subsystem is
begin
end architecture rtl;
