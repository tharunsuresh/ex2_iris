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

library std;
use std.env.stop;

use work.spi_types.all;
use work.vnir_base.all;
use work.frame_requester_pkg.all;

use work.vnir.FRAGMENT_WIDTH;

entity frame_requester_tb is
end entity;


architecture tests of frame_requester_tb is	    
    signal clock            : std_logic := '0';  -- Main clock
    signal reset_n          : std_logic := '1';  -- Main reset
    signal config           : config_t;
    signal start_config     : std_logic := '0';
    signal config_done      : std_logic;
    signal do_imaging       : std_logic := '0';
    signal imaging_done     : std_logic;
    signal frame_request    : std_logic;
    signal exposure_start   : std_logic;
    signal status           : status_t;
    
    component frame_requester_mainclock is
    generic (
        FRAGMENT_WIDTH      : integer := FRAGMENT_WIDTH;
        CLOCKS_PER_SEC      : integer
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        config              : in config_t;
        start_config        : in std_logic;
        config_done         : out std_logic;
        do_imaging          : in std_logic;
        imaging_done        : out std_logic;
        frame_request       : out std_logic;
        exposure_start      : out std_logic;
        status              : out status_t
    ); 
    end component frame_requester_mainclock;
    
    pure function in_range(x : time; low : time; high : time) return boolean is
    begin
        return low <= x and x <= high;
    end function in_range;

    constant CLOCK_PERIOD : time := 20 ns;
    constant CLOCKS_PER_SEC : integer := 50000000;

    constant SCLOCK_PERIOD : time := 20.83333 ns;
    constant SCLOCKS_PER_SEC : integer := 48000000;

begin

    debug : process
    begin
        wait until rising_edge(clock);
        if do_imaging = '1' then
            report "Detected do_imaging = 1";
        end if;
        if frame_request = '1' then
            report "Detected frame_request = 1";
        end if;
        if exposure_start = '1' then
            report "Detected exposure_start = 1";
        end if;
    end process debug;

    clock_gen : process
	begin
		wait for CLOCK_PERIOD / 2;
		clock <= not clock;
    end process clock_gen;
    
    test : process

        procedure test (NUM_FRAMES : integer; REQUESTED_EXPOSURE_TIME : time; REQUESTED_FRAME_TIME : time) is
            constant EXTRA_EXPOSURE_TIME : time := (129.0*0.43*20.0) * SCLOCK_PERIOD;
            variable i_frame : integer := 0;
            variable i_exposure : integer := 0;
            variable last_exposure : time := 0 ns;
            variable last_frame_request : time := 0 ns;
            variable frame_time : time := 0 ns;
            variable exposure_time : time := 0 ns;
            variable exit_time : time := 0 ns;
            variable expecting_frame_request : boolean := false;
        begin

            reset_n <= '0'; wait until rising_edge(clock); reset_n <= '1';
            config <= (num_frames => NUM_FRAMES, frame_clocks => REQUESTED_FRAME_TIME / CLOCK_PERIOD, exposure_clocks => REQUESTED_EXPOSURE_TIME / CLOCK_PERIOD);
            start_config <= '1'; wait until rising_edge(clock); start_config <= '0';
            wait until rising_edge(clock) and config_done = '1';

            do_imaging <= '1'; wait until rising_edge(clock); do_imaging <= '0';
            
            while exit_time = 0 ns or now < exit_time loop
                wait until rising_edge(clock);

                if frame_request = '1' then
                    assert expecting_frame_request;
                    assert exposure_start = '0';

                    if last_exposure /= 0 ns then
                        exposure_time := now - last_exposure + EXTRA_EXPOSURE_TIME;
                        report "Exposure time = " & time'image(exposure_time);
                        assert in_range(exposure_time, REQUESTED_EXPOSURE_TIME - CLOCK_PERIOD, REQUESTED_EXPOSURE_TIME + CLOCK_PERIOD);
                    end if;
                    if last_frame_request /= 0 ns then
                        frame_time := now - last_frame_request;
                        report "Frame time = " & time'image(frame_time);
                        assert frame_time = REQUESTED_FRAME_TIME;
                    end if;
                    last_frame_request := now;
                    i_frame := i_frame + 1;
                    expecting_frame_request := false;
                end if;
                
                if exposure_start = '1' then
                    assert not expecting_frame_request;
                    assert frame_request = '0';

                    last_exposure := now;
                    i_exposure := i_exposure + 1;
                    expecting_frame_request := true;
                end if;

                if imaging_done = '1' then
                    exit_time := now + 5 * CLOCK_PERIOD;
                end if;

            end loop;

            assert i_frame = NUM_FRAMES;
            assert i_exposure = NUM_FRAMES;

        end procedure test;

    begin
        test(5, 7 ms, 10 ms);
        test(10, 3 ms, 5 ms);
        test(100, 1 ms, 2.611 ms);
        stop;

	end process test;

    frame_requester_component : frame_requester_mainclock generic map (
        CLOCKS_PER_SEC => CLOCKS_PER_SEC
    ) port map(
        clock => clock,
        reset_n => reset_n,
        config => config,
        start_config => start_config,
        config_done => config_done,
        do_imaging => do_imaging,
        imaging_done => imaging_done,
        frame_request => frame_request,
        exposure_start => exposure_start,
        status => status
    );

end tests;
