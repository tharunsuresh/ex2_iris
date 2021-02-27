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

library std;
use std.env.stop;

use work.spi_types.all;
use work.vnir_base.all;
use work.pixel_integrator_pkg.all;

use work.vnir.ROW_WIDTH;
use work.vnir.FRAGMENT_WIDTH;
use work.vnir.PIXEL_BITS;
use work.vnir.N_WINDOWS;
use work.vnir.MAX_WINDOW_SIZE;


entity pixel_integrator_sum_tb is
end entity pixel_integrator_sum_tb;

architecture tests of pixel_integrator_sum_tb is

    constant ROW_PIXEL_BITS : integer := 20;

    signal clock                : std_logic := '0';
    signal reset_n              : std_logic := '0';
	signal config               : config_t;
    signal read_config          : std_logic := '0';
    signal start                : std_logic := '0';
    signal done                 : std_logic := '0';
    signal fragment             : pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
	signal fragment_available   : std_logic := '0';
    signal row                  : pixel_vector_t(ROW_WIDTH-1 downto 0)(ROW_PIXEL_BITS-1 downto 0);
    signal row_window           : integer;
    signal status               : status_t;

    component pixel_integrator is
    generic (
        ROW_WIDTH           : integer := ROW_WIDTH;
        FRAGMENT_WIDTH      : integer := FRAGMENT_WIDTH;
        PIXEL_BITS          : integer := PIXEL_BITS;
        ROW_PIXEL_BITS      : integer := ROW_PIXEL_BITS;
        N_WINDOWS           : integer := N_WINDOWS;
        METHOD              : string := "SUM";
        MAX_WINDOW_SIZE     : integer := MAX_WINDOW_SIZE
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        config              : in config_t;
        read_config         : in std_logic;
        start               : in std_logic;
        done                : out std_logic;
        fragment            : in pixel_vector_t;
        fragment_available  : in std_logic;
        row                 : out pixel_vector_t;
        row_window          : out integer;
        status              : out status_t
    );
    end component pixel_integrator;

    procedure readline(file f : text; row : out pixel_vector_t) is
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
        for i in 0 to N_WINDOWS-1 loop
            readline(f, f_line);
            read(f_line, config.windows(i).lo);
            read(f_line, config.windows(i).hi);
        end loop;

        readline(f, f_line);
        read(f_line, config.length);
    end procedure read;

    procedure read(file f : text; i : out integer) is
        variable f_line : line;
    begin
        readline(f, f_line);
        read(f_line, i);
    end procedure read;

    constant OUT_DIR : string := "../subsystems/vnir/tests/out/pixel_integrator/";

begin

	-- Generate main clock signal
    clock_gen : process
        constant CLOCK_PERIOD : time := 20 ns;
	begin
		wait for CLOCK_PERIOD / 2;
		clock <= not clock;
	end process clock_gen;

    check_output : process
        file colour0_file : text open read_mode is OUT_DIR & "sum/colour0.out";
        file colour1_file : text open read_mode is OUT_DIR & "sum/colour1.out";
        file colour2_file : text open read_mode is OUT_DIR & "sum/colour2.out";
        variable file_row : pixel_vector_t(ROW_WIDTH-1 downto 0)(ROW_PIXEL_BITS-1 downto 0);
    begin
        assert N_WINDOWS = 3;
        wait until reset_n = '1';

        loop
            wait until rising_edge(clock) and row_window >= 0;
            report "Recieved row " & integer'image(row_window);

            case row_window is
                when 0 => readline(colour0_file, file_row);
                when 1 => readline(colour1_file, file_row);
                when 2 => readline(colour2_file, file_row);
                when others => report "Invalid row_index" severity failure;
            end case;

            assert row = file_row report "Recieved mismatched row" severity error;

            exit when done = '1';
        end loop;

        assert endfile(colour0_file) and
               endfile(colour1_file) and
               endfile(colour2_file);
        stop;
        
    end process;

    gen_input : process
        constant N_FRAGMENTS : integer := ROW_WIDTH / FRAGMENT_WIDTH;
        variable tests_passed : boolean := true;
        variable row : pixel_vector_t(ROW_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
        file row_file : text open read_mode is OUT_DIR & "rows.out";
        file config_file : text open read_mode is OUT_DIR & "config.out";
        
        variable config_v : config_t;
    begin
        read(config_file, config_v);

        wait until rising_edge(clock);
        reset_n <= '1';
        wait until rising_edge(clock);

        config <= config_v;
        read_config <= '1';
        wait until rising_edge(clock);
        read_config <= '0';

        report "Uploading started";
        start <= '1';
        wait until rising_edge(clock);
        start <= '0';

        fragment_available <= '1';
        while not endfile(row_file) loop
            readline(row_file, row);

            for f in 0 to N_FRAGMENTS-1 loop
                for i in 0 to FRAGMENT_WIDTH-1 loop
                    fragment(i) <= row(f + N_FRAGMENTS * i);
                end loop;
                wait until rising_edge(clock);
            end loop;
        end loop;
        fragment_available <= '0';
        report "Uploading finished";
        wait;
    end process;

    pixel_integrator_component : pixel_integrator port map (
        clock => clock,
        reset_n => reset_n,
        config => config,
        read_config => read_config,
        start => start,
        done => done,
        fragment => fragment,
        fragment_available => fragment_available,
        row => row,
        row_window => row_window,
        status => status
    );

end tests;
