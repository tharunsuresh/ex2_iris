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


package pulse_generator_pkg is
    type state_t is (IDLE, DELAYING, RUNNING);

    type status_t is record
        state   : state_t;
    end record status_t;
end package pulse_generator_pkg;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pulse_generator_pkg.all;

-- Produces periodic pulses at a fixed fps
--
-- To use, set `frequency_Hz` to the required fps, `initial_delay_clocks`
-- to the number of clocks to delay before beginning to pulse (i.e. the
-- phase of the resulting waveform), and `n_pulses` to the number of
-- times you want `pulse_generator` to produce an output pulse before
-- returning to it's idle state. Then, assert `start`, and the desired
-- pulses will be produced on the `pulses_out` output. When the
-- `pulse_generator` is finished, it will hold `done` high for a single
-- clock cycle
--
-- `status` contains the current status of the `pulse_generator`, to
-- be used for debugging
entity pulse_generator is
port (
    clock                   : in std_logic;
    reset_n                 : in std_logic;

    period_clocks           : in integer;
    initial_delay_clocks    : in integer;
    n_pulses                : in integer;

    start                   : in std_logic;
    done                    : out std_logic;

    pulses_out              : out std_logic;

    status                  : out status_t
);
end entity pulse_generator;


architecture rtl of pulse_generator is
begin

    fsm : process (clock, reset_n)
        variable state : state_t;
        
        variable pulses_remaining   : integer;
        variable delay_remaining    : integer;
        variable period_remaining   : integer;
    begin
        if reset_n = '0' then
            state := IDLE;
            pulses_out <= '0';
            done <= '0';
        elsif rising_edge(clock) then
            pulses_out <= '0';
            done <= '0';
            case state is
            when IDLE =>
                if start = '1' then
                    pulses_remaining := n_pulses;
                    delay_remaining  := initial_delay_clocks;
                    period_remaining := 0;  -- Trigger initial pulse
                    if delay_remaining > 0 then
                        state := DELAYING;
                    else
                        state := RUNNING;
                    end if;
                end if;
            when DELAYING =>
                if delay_remaining = 1 then
                    state := RUNNING;
                end if;
                delay_remaining := delay_remaining - 1;
            when RUNNING =>
                if pulses_remaining = 0 then
                    state := IDLE;
                    done <= '1';
                elsif period_remaining = 0 then
                    pulses_remaining := pulses_remaining - 1;
                    period_remaining := period_clocks;
                    pulses_out <= '1';
                end if;
                period_remaining := period_remaining - 1;
            end case;
        end if;

        status.state <= state;
    end process fsm;

end architecture rtl;
