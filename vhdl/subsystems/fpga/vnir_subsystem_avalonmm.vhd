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

-- Interface to the VNIR Subsystem using an AvalonMM slave instead of
-- dedicated configuration and command ports


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.spi_types.all;
use work.vnir;
use work.sensor_configurer_defaults;

entity vnir_subsystem_avalonmm is
generic (
    CLOCKS_PER_SEC      : integer := 50000000;

    POWER_ON_DELAY_us   : integer := sensor_configurer_defaults.POWER_ON_DELAY_us;
    CLOCK_ON_DELAY_us   : integer := sensor_configurer_defaults.CLOCK_ON_DELAY_us;
    RESET_OFF_DELAY_us  : integer := sensor_configurer_defaults.RESET_OFF_DELAY_us;
    SPI_SETTLE_us       : integer := sensor_configurer_defaults.SPI_SETTLE_us
);
port (
    clock               : in std_logic;
    reset_n             : in std_logic;

    avs_address         : in  std_logic_vector(7 downto 0);
    avs_read            : in  std_logic := '0';
    avs_readdata        : out std_logic_vector(31 downto 0);
    avs_write           : in  std_logic := '0';
    avs_writedata       : in  std_logic_vector(31 downto 0);
    avs_irq             : out std_logic;

    sensor_clock        : in std_logic;
    sensor_power        : out std_logic;
    sensor_clock_enable : out std_logic;
    sensor_reset_n      : out std_logic;

    row                 : out vnir.row_t;
    row_available       : out vnir.row_type_t;
    
    spi_out             : out spi_from_master_t;
    spi_in              : in spi_to_master_t;
    
    frame_request       : out std_logic;
    exposure_start      : out std_logic;
    lvds                : in vnir.lvds_t
);
end entity vnir_subsystem_avalonmm;


architecture rtl of vnir_subsystem_avalonmm is

    component vnir_controller is
    port (
        clock               : in std_logic;
        reset_n             : in std_logic := '0';

        avs_address         : in  std_logic_vector(7 downto 0);
        avs_read            : in  std_logic := '0';
        avs_readdata        : out std_logic_vector(31 downto 0);
        avs_write           : in  std_logic := '0';
        avs_writedata       : in  std_logic_vector(31 downto 0);
        avs_irq             : out std_logic;

        config              : out vnir.config_t;
        start_config        : out std_logic;
        config_done         : in  std_logic;

        image_config        : out vnir.image_config_t;
        start_image_config  : out std_logic;
        image_config_done   : in  std_logic;

        do_imaging          : out std_logic;
        imaging_done        : in  std_logic;

        status              : in  vnir.status_t
    );
    end component vnir_controller;

    component vnir_subsystem is
    generic (
        CLOCKS_PER_SEC      : integer := CLOCKS_PER_SEC;

        POWER_ON_DELAY_us   : integer := POWER_ON_DELAY_us;
        CLOCK_ON_DELAY_us   : integer := CLOCK_ON_DELAY_us;
        RESET_OFF_DELAY_us  : integer := RESET_OFF_DELAY_us;
        SPI_SETTLE_us       : integer := SPI_SETTLE_us
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
    
        sensor_clock        : in std_logic;
        sensor_power        : out std_logic;
        sensor_clock_enable : out std_logic;
        sensor_reset_n      : out std_logic;
    
        config              : in vnir.config_t;
        start_config        : in std_logic;
        config_done         : out std_logic;
        
        image_config        : in vnir.image_config_t;
        start_image_config  : in std_logic;
        image_config_done   : out std_logic;
        
        do_imaging          : in std_logic;
        imaging_done        : out std_logic;
    
        row                 : out vnir.row_t;
        row_available       : out vnir.row_type_t;
        
        spi_out             : out spi_from_master_t;
        spi_in              : in spi_to_master_t;
        
        frame_request       : out std_logic;
        exposure_start      : out std_logic;
        lvds                : in vnir.lvds_t;
    
        status              : out vnir.status_t
    );
    end component vnir_subsystem;

    signal config               : vnir.config_t;
    signal start_config         : std_logic;
    signal config_done          : std_logic;
    signal image_config         : vnir.image_config_t;
    signal start_image_config   : std_logic;
    signal image_config_done    : std_logic;
    signal do_imaging           : std_logic;
    signal imaging_done         : std_logic;
    signal status               : vnir.status_t;

begin

    vnir_controller_cmp : vnir_controller port map (
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

        image_config => image_config,
        start_image_config => start_image_config,
        image_config_done => image_config_done,

        do_imaging => do_imaging,
        imaging_done => imaging_done,

        status => status
    );

    vnir_subsystem_cmp : vnir_subsystem port map (
        clock => clock,
        reset_n => reset_n,

        sensor_clock => sensor_clock,
        sensor_power => sensor_power,
        sensor_clock_enable => sensor_clock_enable,
        sensor_reset_n => sensor_reset_n,
        
        config => config,
        start_config => start_config,
        config_done => config_done,

        image_config => image_config,
        start_image_config => start_image_config,
        image_config_done => image_config_done,

        do_imaging => do_imaging,
        imaging_done => imaging_done,

        row => row,
        row_available => row_available,
        
        spi_out => spi_out,
        spi_in => spi_in,

        frame_request => frame_request,
        exposure_start => exposure_start,
        lvds => lvds,

        status => status
    );

end architecture rtl;
