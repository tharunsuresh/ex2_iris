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
use std.textio.all;
use ieee.std_logic_misc.all;

library std;
use std.env.stop;

use work.spi_types.all;
use work.vnir_base;
use work.vnir.all;

use work.sensor_configurer_pkg.FLIP_NONE;

entity vnir_subsystem_tb is
end entity;


architecture tests of vnir_subsystem_tb is
    constant OUT_DIR : string := "../subsystems/vnir/tests/out/vnir_subsystem/";

    signal clock                : std_logic := '0';  -- Main clock
    signal reset_n              : std_logic := '0';  -- Main reset
    signal sensor_clock_source  : std_logic := '0';
    signal sensor_clock         : std_logic := '0';
    signal sensor_power         : std_logic;
    signal sensor_clock_enable  : std_logic;
    signal sensor_reset_n       : std_logic;
    signal config               : config_t;
    signal start_config         : std_logic := '0';
    signal config_done          : std_logic;
    signal image_config         : image_config_t;
    signal start_image_config   : std_logic := '0';
    signal image_config_done    : std_logic;
    signal do_imaging           : std_logic := '0';
    signal imaging_done         : std_logic;
    signal num_rows             : integer;
    signal row                  : row_t;
    signal row_available        : row_type_t;
    signal spi                  : spi_t;
    signal frame_request        : std_logic;
    signal exposure_start       : std_logic;
    signal lvds                 : lvds_t := (
        clock => '0', control => '0',
        data => (others => '0')
    );
    signal status               : status_t;
    
    component vnir_subsystem is
    generic (
        POWER_ON_DELAY_us   : integer := 0;
        CLOCK_ON_DELAY_us   : integer := 0;
        RESET_OFF_DELAY_us  : integer := 0;
        SPI_SETTLE_us       : integer := 0
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
    
        sensor_clock        : in std_logic;
        sensor_power        : out std_logic;
        sensor_clock_enable : out std_logic;
        sensor_reset_n      : out std_logic;
        config              : in config_t;
        start_config        : in std_logic;
        config_done         : out std_logic;
        image_config        : in image_config_t;
        start_image_config  : in std_logic;
        image_config_done   : out std_logic;
        num_rows            : out integer;
        do_imaging          : in std_logic;
        imaging_done        : out std_logic;
        row                 : out row_t;
        row_available       : out row_type_t;
        spi_out             : out spi_from_master_t;
        spi_in              : in spi_to_master_t;
        frame_request       : out std_logic;
        exposure_start      : out std_logic;
        lvds                : in lvds_t;
        status              : out status_t
    );
    end component;

    pure function total_rows(config : config_t) return integer is
    begin
        return vnir_base.size(config.window_red) +
               vnir_base.size(config.window_nir) + 
               vnir_base.size(config.window_blue);
    end function total_rows;

    procedure readline(file f : text; row : out row_t) is
        variable f_line : line;
        variable pixel : integer;
    begin
        readline(f, f_line);
        for i in row'range loop
            read(f_line, pixel);
            row(i) := to_unsigned(pixel, row(i)'length);
        end loop;
    end procedure readline;

    procedure read(file f : text; config : out config_t) is
        variable f_line : line;
        variable i : integer;
    begin
        readline(f, f_line);
        read(f_line, config.window_red.lo);
        read(f_line, config.window_red.hi);
        
        readline(f, f_line);
        read(f_line, config.window_nir.lo);
        read(f_line, config.window_nir.hi);

        readline(f, f_line);
        read(f_line, config.window_blue.lo);
        read(f_line, config.window_blue.hi);
    end procedure read;

    procedure read(file f : text; i : out integer) is
        variable f_line : line;
    begin
        readline(f, f_line);
        read(f_line, i);
    end procedure read;

    pure function "=" (lhs : vnir_base.pixel_t; rhs : vnir_base.pixel_t) return boolean is
        variable re : boolean := true;
    begin
        for i in lhs'range loop
           re := re and (lhs(i) = rhs(i));
        end loop;
        return re;
    end function "=";

    pure function "=" (lhs : vnir_base.pixel_vector_t; rhs : vnir_base.pixel_vector_t) return boolean is
        variable re : boolean := true;
    begin
        for i in lhs'range loop
            re := re and (lhs(i) = rhs(i));
        end loop;
        return re;
    end function "=";

begin

    sensor_clock <= sensor_clock_source and sensor_clock_enable;

    debug : process (clock)
    begin
        if rising_edge(clock) then
            if do_imaging = '1' then
                report "do_imaging = 1";
            end if;
            if imaging_done = '1' then
                report "imaging_done = 1";
            end if;
            if frame_request = '1' then
                report "frame_request = 1";
            end if;
            if exposure_start = '1' then
                report "exposure_start = 1";
            end if;
            if row_available = ROW_NIR then
                report "row available = NIR";
            end if;
            if row_available = ROW_BLUE then
                report "row available = BLUE";
            end if;
            if row_available = ROW_RED then
                report "row available = RED";
            end if;
        end if;
    end process debug;

    reciever : process
        file nir_file : text open read_mode is OUT_DIR & "nir.out";
        file blue_file : text open read_mode is OUT_DIR & "blue.out";
        file red_file : text open read_mode is OUT_DIR & "red.out";
        variable file_row : row_t;
    begin
        wait until rising_edge(clock) and do_imaging = '1';

        loop
            wait until rising_edge(clock);
            if row_available = ROW_NIR then
                report "Recieved NIR row";
                assert not endfile(nir_file) report "Received extra NIR row" severity failure;
                readline(nir_file, file_row);
                assert row = file_row report "Received mismatched NIR row" severity failure;
            elsif row_available = ROW_BLUE then
                report "Recieved blue row";
                assert not endfile(blue_file) report "Received extra blue row" severity failure;
                readline(blue_file, file_row);
                assert row = file_row report "Received mismatched blue row" severity failure;
            elsif row_available = ROW_RED then
                report "Recieved red row";
                assert not endfile(red_file) report "Received extra red row" severity failure;
                readline(red_file, file_row);
                assert row = file_row report "Received mismatched red row" severity failure;
            end if;
            exit when imaging_done = '1';
        end loop;

        assert endfile(nir_file) and endfile(blue_file) and endfile(red_file);
        stop;
    end process;

    clock_gen : process
        constant CLOCK_PERIOD : time := 20 ns;
	begin
		wait for CLOCK_PERIOD / 2;
		clock <= not clock;
    end process clock_gen;
    
    sensor_clock_gen : process
        constant sensor_CLOCK_PERIOD : time := 20.83 ns;
    begin
        wait for sensor_CLOCK_PERIOD / 2;
        sensor_clock_source <= not sensor_clock_source;
    end process sensor_clock_gen;

    lvds_clock_gen : process
        constant lvds_CLOCK_PERIOD : time := 4.167 ns;
    begin
        wait for lvds_CLOCK_PERIOD / 2;
        lvds.clock <= not lvds.clock;
    end process lvds_clock_gen;

    sensor : process
        constant FRAGMENTS_PER_ROW : integer := ROW_WIDTH / FRAGMENT_WIDTH;
        constant CONTROL_IDLE : pixel_t := (9 => '1', others => '0');
        constant CONTROL_DATA : pixel_t := (0 => '1', 9 => '1', others => '0');

        type state_t is (IDLE, EMITTING_FRAME);
        variable state : state_t := IDLE;
        variable next_state : state_t := IDLE;

        file row_file : text open read_mode is OUT_DIR & "rows.out";
        variable row : row_t;
        variable i_row : integer;
    begin
        if state = EMITTING_FRAME then
            readline(row_file, row);
        end if;

        for i_fragment in 0 to FRAGMENTS_PER_ROW-1 loop
            for i_bit in 0 to PIXEL_BITS-1 loop
                wait until rising_edge(lvds.clock) or falling_edge(lvds.clock);
                
                case state is
                when IDLE =>
                    lvds.control <= CONTROL_IDLE(i_bit);
                    if frame_request = '1' then
                        next_state := EMITTING_FRAME;
                    end if;
                when EMITTING_FRAME =>
                    lvds.control <= CONTROL_DATA(i_bit);
                    for i_channel in 0 to FRAGMENT_WIDTH-1 loop
                        lvds.data(i_channel) <= row(i_fragment + i_channel * FRAGMENTS_PER_ROW)(i_bit);
                    end loop;
                end case;
            end loop;
        end loop;

        if state /= EMITTING_FRAME and next_state = EMITTING_FRAME then
            i_row := 0;
        end if;

        if state = EMITTING_FRAME then
            i_row := i_row + 1;
            if i_row = total_rows(config) then
                next_state := IDLE;
            end if;
        end if;

        state := next_state;

    end process;

    test : process
        file config_file : text open read_mode is OUT_DIR & "config.out";
        file image_length_file : text open read_mode is OUT_DIR & "image_length.out";

        variable config_v : config_t;
        variable image_length_v : integer;
    begin
        read(config_file, config_v);
        read(image_length_file, image_length_v);
        
        wait until rising_edge(clock); reset_n <= '0'; wait until rising_edge(clock); reset_n <= '1';
        wait until rising_edge(clock);
        config <= config_v;
        config.flip <= FLIP_NONE;
        config.calibration <= (v_ramp1 => 109, v_ramp2 => 109, offset => 16323, adc_gain => 32);
        start_config <= '1'; wait until rising_edge(clock); start_config <= '0'; 
        wait until rising_edge(clock) and config_done = '1';

        image_config <= (length => 2, frame_clocks => 3000, exposure_clocks => 2000);
        start_image_config <= '1';  wait until rising_edge(clock); start_image_config <= '0'; 
        wait until rising_edge(clock) and num_rows /= 0;
        assert image_length_v = num_rows;
        wait until rising_edge(clock) and image_config_done = '1';
        
        do_imaging <= '1'; wait until rising_edge(clock); do_imaging <= '0';

        wait;
	end process test;

	u0 : vnir_subsystem port map (
        clock => clock,
        reset_n => reset_n,
        sensor_clock => sensor_clock_source,
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
        num_rows => num_rows,
        row => row,
        row_available => row_available,
        spi_out => spi.from_master,
        spi_in => spi.to_master,
        frame_request => frame_request,
        exposure_start => exposure_start,
        lvds => lvds,
        status => status
    );

end tests;
