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


-- Microsecond-accurate delay timer
entity timer is
generic (
    CLOCKS_PER_SEC  : integer;
    DELAY_uS        : integer
);
port (
    clock   : in std_logic;
    reset_n : in std_logic;
    start   : in std_logic;
    done    : out std_logic
);
end entity timer;


architecture rtl of timer is
begin

    fsm : process (clock, reset_n)
        constant uS_PER_S : integer := 1000000;
        type state_t is (IDLE, WAITING);
        variable state : state_t;
        variable clocks_waited : integer;

        constant CLOCKS_TO_WAIT : integer := to_integer(
            to_unsigned(DELAY_uS, 64) * to_unsigned(CLOCKS_PER_SEC, 64) / to_unsigned(uS_PER_S, 64)
        );

    begin
        if reset_n = '0' then
            state := IDLE;
            done <= '0';
        elsif rising_edge(clock) then
            done <= '0';
            case state is
            when IDLE =>
                if start = '1' then
                    state := WAITING;
                    clocks_waited := 1;
                end if;
            when WAITING =>
                if clocks_waited  >= CLOCKS_TO_WAIT then
                    state := IDLE;
                    done <= '1';
                end if;
                clocks_waited := clocks_waited + 1;
            end case;
        end if;
    end process fsm;

end architecture rtl;
