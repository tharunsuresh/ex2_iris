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

use work.vnir_base.all;
use work.frame_requester_pkg.all;
use work.pulse_generator_pkg;


-- Like `frame_requester`, but operates entirely in a single clock
-- domain. See `frame_requester` for an overview of this entity's
-- functionality.
entity frame_requester_mainclock is
generic (
    FRAGMENT_WIDTH      : integer;
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

    status              : out status_t;
    
    frame_request       : out std_logic;
    exposure_start      : out std_logic
);
end entity frame_requester_mainclock;

architecture rtl of frame_requester_mainclock is

    component pulse_generator is
    port (
        clock                   : in std_logic;
        reset_n                 : in std_logic;
        period_clocks           : in integer;
        initial_delay_clocks    : in integer;
        n_pulses                : in integer;
        start                   : in std_logic;
        done                    : out std_logic;
        pulses_out              : out std_logic;
        status                  : out pulse_generator_pkg.status_t
    );
    end component pulse_generator;

    -- Calculates the offset (in clocks) between the exposure_start signal and the
    -- frame_request signal. According section 5.1 of the user manual, this is almost
    -- (but not quite) the same as the exposure time.
    --
    -- The exposure time in sensor clocks is given by the equation:
    --
    --               exposure_time = 129*0.43*20 + frame_request_offset
    --                             < 1110 + frame_request_offset
    --
    -- which allows us to go backward from the desired exposure time to get the
    -- needed frame request offset.
    pure function calc_frame_request_offset (config : config_t) return integer is
        constant SCLOCKS_PER_SEC : integer := 48000000;  -- TODO: set properly
        constant CLOCKS_PER_SCLOCKS : real := real(CLOCKS_PER_SEC) / real(SCLOCKS_PER_SEC);
        constant EXTRA_EXPOSURE_CLOCKS : integer := integer(
            129.0 * 0.43 * 20.0 * CLOCKS_PER_SCLOCKS
        );
        constant FOT_CLOCKS : integer := integer(
            (20.0 + 2.0 * 16.0 / real(FRAGMENT_WIDTH)) * CLOCKS_PER_SCLOCKS
        );
    begin
        if config.exposure_clocks - EXTRA_EXPOSURE_CLOCKS <= 0 then
            report "Can't compute frame_request_offset: requested exposure is too low" severity failure;
            return 1;
        end if;

        if config.exposure_clocks - EXTRA_EXPOSURE_CLOCKS + FOT_CLOCKS > config.frame_clocks then
            report "Can't compute frame_request_offset: requested exposure is too high" severity failure;
            return config.frame_clocks - FOT_CLOCKS;
        end if;

        return config.exposure_clocks - EXTRA_EXPOSURE_CLOCKS;
    end function calc_frame_request_offset;

    signal frame_request_offset : integer;
    signal config_reg           : config_t;

begin

    fsm : process (clock, reset_n)
        variable state : state_t;
    begin
        if reset_n = '0' then
            config_done <= '0';
        elsif rising_edge(clock) then
            config_done <= '0';
            if start_config = '1' then
                config_reg <= config;
                frame_request_offset <= calc_frame_request_offset(config);
                config_done <= '1';
            end if;
        end if;

        status.state <= state;
    end process fsm;

    frame_request_gen : pulse_generator port map (
        clock => clock,
        reset_n => reset_n,
        period_clocks => config_reg.frame_clocks,
        initial_delay_clocks => frame_request_offset,
        n_pulses => config_reg.num_frames,
        start => do_imaging,
        done => imaging_done,
        pulses_out => frame_request,
        status => status.frame_request
    );

    -- Source of `exposure_start` pulses
    exposure_start_gen : pulse_generator port map (
        clock => clock,
        reset_n => reset_n,
        period_clocks => config_reg.frame_clocks,
        initial_delay_clocks => 0,
        n_pulses => config_reg.num_frames,
        start => do_imaging,
        done => open,
        pulses_out => exposure_start,
        status => status.exposure_start
    );


end architecture rtl;
