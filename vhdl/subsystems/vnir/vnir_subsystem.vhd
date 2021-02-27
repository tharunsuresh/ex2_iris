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
use ieee.math_real.all;

use work.spi_types.all;

use work.vnir_base.all;
use work.pixel_integrator_pkg;
use work.sensor_configurer_pkg;
use work.sensor_configurer_defaults;
use work.lvds_decoder_pkg;
use work.frame_requester_pkg;
use work.vnir;


-- Top-level VNIR sensor subsystem component
--
-- Along with the `vnir` package, provides the interface through which
-- external subsystems interact with the VNIR subsystem.
--
-- Parameters
-- ----------
-- clock [in]
--     Main clock, must be >= 48MHz.
--
-- reset_n [in]
--     Synchronous, active-low reset. Both clocks must be running before
--      reset_n is set to '1'.
--
-- sensor_clock [in]
--     48MHz clock for sensor control input.
--
-- sensor_power [out]
--     Will be held at '1' when the `vnir_subsystem` needs
--     to enable the sensor's various voltage inputs.
--
-- sensor_clock_enable [out]
--     Will be held at '1' when the `vnir_subsystem` needs the sensor to
--     recieve a clock input. Note that the `sensor_clock` input is
--     always required to be on, regardless of of the value of this
--     input -- `sensor_clock_enable` is to be used to gate the clock
--     input of the sensor, not of `vnir_subsystem`.
--
-- sensor_reset_n [out]
--     Sensor reset signal
--
-- config [in]
--     Configuration values. Allows setting the positions and widths of
--     the red, blue and NIR windows, and the sensor calibration values.
--
-- start_config [in]
--     Hold at '1' for a single clock cycle to begin configuring, which
--     will initialize all the various components of `vnir_subsystem`.
--     The `config` input will be read and its values used to control
--     the configuration sequence.
--     Configuration may only occur after a reset, or after imaging has
--     been requested, then finished.
--
-- config_done [out]
--     Held high for a single clock cycle when the `vnir_subsystem` is
--     finished configuring.
--
-- image_config [in]
--     Image-configuration values. Allows setting per-image
--     configuration values: duration, fps, and exposure time.
--
-- start_image_config [in]
--     Hold high for a single clock cycle to begin initializing per-
--     image configuration.
--     Per-image configuration must occur after general configuration
--     has finished, and not while `vnir_subsystem` is imaging.
--
-- image_config_done [out]
--     Held high for a single clock cycle when the `vnir_subsystem` has
--     finished per-image configuration.
--
-- num_rows [out]
--     Set for a single clock cycle at some point during per-image
--     configuration to the number of rows of the output image
--     (calculated from the fps and imaging duration). Set to 0 for all
--     other clock cycles.
--
-- do_imaging [in]
--     Hold high for a single clock cycle to enter imaging mode (after
--     doing both general and per-image configuration). `vnir_subsystem`
--     will repeatedly request frames from the sensor, process the
--     resulting frames, and make the image available on the `row` and
--     `row_available` outputs.
--
-- imaging_done [out]
--     Held high for a single clock cycle to indicate when imaging mode
--     is done.
--
-- row [out]
--     When in imaging mode, will yield the output image row by row.
--
-- row_available [out]
--     When set to something other than ROW_NONE, indicates that the
--     `row` output contains valid data to be read. Indicates which
--     window the row in question belongs to (red, blue or NIR).
--     Will be set to non-ROW_NONE values for only single clock cycles.
--
-- spi_out [out]
--     SPI output signals to the VNIR sensor
--
-- spi_in [in]
--     SPI input signals from the VNIR sensor
--
-- frame_request [out]
--     To be attached to the sensor's frame-request signal. Indicates
--     that the sensor should stop exposure and eventually emit a new
--     frame.
--
-- exposure_start [out]
--     To be attached to the sensor's exposure-start signal. Indicates
--     that the sensor should start exposing a new frame.
--
-- lvds [in]
--     LVDS input from the sensor. This is how the sensor gives the
--     `vnir_subsystem` image data.
--
-- status
--     Status register, for debugging
entity vnir_subsystem is
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
    num_rows            : out integer;
    
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
end entity vnir_subsystem;


architecture rtl of vnir_subsystem is

    component sensor_configurer is
    generic (
        FRAGMENT_WIDTH      : integer := vnir.FRAGMENT_WIDTH;
        PIXEL_BITS          : integer := vnir.PIXEL_BITS;
        N_WINDOWS           : integer := vnir.N_WINDOWS;
        CLOCKS_PER_SEC      : integer := CLOCKS_PER_SEC;
        POWER_ON_DELAY_us   : integer := POWER_ON_DELAY_us;
        CLOCK_ON_DELAY_us   : integer := CLOCK_ON_DELAY_us;
        RESET_OFF_DELAY_us  : integer := RESET_OFF_DELAY_us;
        SPI_SETTLE_us       : integer := SPI_SETTLE_us
    );
    port (	
        clock               : in std_logic;
        reset_n             : in std_logic;
        config              : in sensor_configurer_pkg.config_t;
        start_config        : in std_logic;
        config_done         : out std_logic;
        spi_out             : out spi_from_master_t;
        spi_in              : in spi_to_master_t;
        sensor_power        : out std_logic;
        sensor_clock_enable : out std_logic;
        sensor_reset_n      : out std_logic;
        status              : out sensor_configurer_pkg.status_t
    );
    end component sensor_configurer;

    component lvds_decoder is
    generic (
        FRAGMENT_WIDTH      : integer := vnir.FRAGMENT_WIDTH;
        PIXEL_BITS          : integer := vnir.PIXEL_BITS
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        start_align         : in std_logic;
        align_done          : out std_logic;
        lvds_clock          : in std_logic;
        lvds_control        : in std_logic;
        lvds_data           : in std_logic_vector;
        fragment            : out pixel_vector_t;
        fragment_control    : out control_t;
        fragment_available  : out std_logic;
        status              : out lvds_decoder_pkg.status_t
    );
    end component lvds_decoder;

    component frame_requester is
    generic (
        FRAGMENT_WIDTH      : integer := vnir.FRAGMENT_WIDTH;
        CLOCKS_PER_SEC      : integer := CLOCKS_PER_SEC
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        config              : in frame_requester_pkg.config_t;
        start_config        : in std_logic;
        config_done         : out std_logic;
        do_imaging          : in std_logic;
        imaging_done        : out std_logic;
        sensor_clock        : in std_logic;
        frame_request       : out std_logic;
        exposure_start      : out std_logic;
        status              : out frame_requester_pkg.status_t
    );
    end component frame_requester;

    component pixel_integrator is
    generic (
        ROW_WIDTH           : integer := vnir.ROW_WIDTH;
        FRAGMENT_WIDTH      : integer := vnir.FRAGMENT_WIDTH;
        PIXEL_BITS          : integer := vnir.PIXEL_BITS;
        ROW_PIXEL_BITS      : integer := vnir.ROW_PIXEL_BITS;
        N_WINDOWS           : integer range 1 to pixel_integrator_pkg.MAX_N_WINDOWS := vnir.N_WINDOWS;
        METHOD              : string := vnir.METHOD;
        MAX_WINDOW_SIZE     : integer := vnir.MAX_WINDOW_SIZE
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        config              : in pixel_integrator_pkg.config_t;
        read_config         : in std_logic;
        start               : in std_logic;
        done                : out std_logic;
        fragment            : in pixel_vector_t;
        fragment_available  : in std_logic;
        row                 : out pixel_vector_t;
        row_window          : out integer;
        status              : out pixel_integrator_pkg.status_t
    );
    end component pixel_integrator;

    signal config_reg       : vnir.config_t;
    signal image_config_reg : vnir.image_config_t := (others => 0);

    signal imaging_done_s : std_logic;

    signal start_frame_requester_config : std_logic;
    signal frame_requester_config       : frame_requester_pkg.config_t;
    signal frame_requester_config_done  : std_logic;

    signal start_sensor_config      : std_logic;
    signal sensor_configurer_config : sensor_configurer_pkg.config_t;
    signal sensor_config_done       : std_logic;

    signal start_align : std_logic;
    signal align_done  : std_logic;

    signal pixel_integrator_config : pixel_integrator_pkg.config_t;

    signal fragment                 : pixel_vector_t(vnir.FRAGMENT_WIDTH-1 downto 0)(vnir.PIXEL_BITS-1 downto 0);
    signal fragment_control         : control_t;
    signal fragment_available       : std_logic;
    
    signal image_length : integer;

    signal row_window   : integer;

begin
    
    -- General config sequence is:
    -- Configure sensor (power on, initialize, etc.) => align LVDS
    -- decoding.

    -- Per-image config sequence is:
    -- Calculate image length => Configure frame-requester (calculate
    -- exposure-start/frame-request scheduling, etc.)

    fsm : process (clock, reset_n)
        variable state : vnir.state_t;
    begin
        if reset_n = '0' then
            start_sensor_config <= '0';
            start_frame_requester_config <= '0';
            config_done <= '0';
            image_config_done <= '0';
            state := vnir.PRE_CONFIG;
        elsif rising_edge(clock) then
            start_sensor_config <= '0';
            start_frame_requester_config <= '0';
            config_done <= '0';
            image_config_done <= '0';

            case state is
            when vnir.PRE_CONFIG =>
                assert start_image_config = '0';
                assert do_imaging = '0';
                if start_config = '1' then
                    config_reg <= config;
                    start_sensor_config <= '1';
                    state := vnir.CONFIGURING;
                end if;
            when vnir.CONFIGURING =>
                assert start_config = '0';
                assert start_image_config = '0';
                assert do_imaging = '0';
                if align_done = '1' then
                    config_done <= '1';
                    state := vnir.PRE_IMAGE_CONFIG;
                end if;
            when vnir.PRE_IMAGE_CONFIG =>
                assert start_config = '0';
                assert do_imaging = '0';
                if start_image_config = '1' then
                    image_config_reg <= image_config;
                    start_frame_requester_config <= '1';
                    num_rows <= image_config.length;
                    state := vnir.IMAGE_CONFIGURING;
                end if;
            when vnir.IMAGE_CONFIGURING =>
                assert start_config = '0';
                assert start_image_config = '0';
                assert do_imaging = '0';
                if frame_requester_config_done = '1' then
                    image_config_done <= '1';
                    state := vnir.IDLE;
                end if;
            when vnir.IDLE =>
                assert (start_config = '0' and start_image_config = '0' and do_imaging = '0') or
                    (start_config = '1' and start_image_config = '0' and do_imaging = '0') or
                    (start_config = '0' and start_image_config = '1' and do_imaging = '0') or
                    (start_config = '0' and start_image_config = '0' and do_imaging = '1');
                    
                if start_config = '1' then
                    config_reg <= config;
                    start_sensor_config <= '1';
                    state := vnir.CONFIGURING;
                end if;
                if start_image_config = '1' then
                    image_config_reg <= image_config;
                    start_frame_requester_config <= '1';
                    num_rows <= image_config.length;
                    state := vnir.IMAGE_CONFIGURING;
                end if;
                if do_imaging = '1' then
                    -- TODO: might want to start the frame_requester here instead of it starting independently
                    state := vnir.IMAGING;
                end if;
            when vnir.IMAGING =>
                assert start_config = '0';
                assert start_image_config = '0';
                assert do_imaging = '0';
                if imaging_done_s = '1' then -- TODO: might want to make sure row_collator is finished
                    state := vnir.IDLE; 
                end if;
            end case;

            status.state <= state;
        end if;
    end process fsm;

    start_align <= sensor_config_done;

    sensor_configurer_component : sensor_configurer port map (
        clock => clock,
        reset_n => reset_n,
        config => sensor_configurer_config,
        start_config => start_sensor_config,
        config_done => sensor_config_done,
        spi_out => spi_out,
        spi_in => spi_in,
        sensor_power => sensor_power,
        sensor_clock_enable => sensor_clock_enable,
        sensor_reset_n => sensor_reset_n,
        status => status.sensor_configurer
    );
    
    frame_requester_component : frame_requester port map (
        clock => clock,
        reset_n => reset_n,
        config => frame_requester_config,
        start_config => start_frame_requester_config,
        config_done => frame_requester_config_done,
        do_imaging => do_imaging,
        sensor_clock => sensor_clock,
        frame_request => frame_request,
        exposure_start => exposure_start,
        status => status.frame_requester
    );

    lvds_decoder_component : lvds_decoder  port map (
        clock => clock,
        reset_n => reset_n,
        start_align => start_align,
        align_done => align_done,
        lvds_clock => lvds.clock,
        lvds_control => lvds.control,
        lvds_data => lvds.data,
        fragment => fragment,
        fragment_control => fragment_control,
        fragment_available => fragment_available,
        status => status.lvds_decoder
    );

    pixel_integrator_component : pixel_integrator port map (
        clock => clock,
        reset_n => reset_n,
        config => pixel_integrator_config,
        read_config => start_frame_requester_config,
        start => do_imaging,
        done => imaging_done_s,
        fragment => fragment,
        fragment_available => fragment_available and fragment_control.dval,
        row => row,
        row_window => row_window,
        status => status.pixel_integrator
    );
    imaging_done <= imaging_done_s;

    sensor_configurer_config <= (
        flip => config_reg.flip,
        calibration => config_reg.calibration,
        windows => (
            0 => config_reg.window_red,
            1 => config_reg.window_nir,
            2 => config_reg.window_blue,
            others => (others => 0)
        )
    );
    frame_requester_config <= (
        num_frames => image_config_reg.length + config_reg.window_blue.hi,
        frame_clocks => image_config_reg.frame_clocks,
        exposure_clocks => image_config_reg.exposure_clocks
    );
    pixel_integrator_config <= (
        length => image_config_reg.length,
        windows => (
            0 => config_reg.window_red,
            1 => config_reg.window_nir,
            2 => config_reg.window_blue,
            others => (others => 0)
        )
    );

    row_available <= vnir.ROW_RED when row_window = 0 else
                     vnir.ROW_NIR when row_window = 1 else
                     vnir.ROW_BLUE when row_window = 2 else
                     vnir.ROW_NONE;

end architecture rtl;