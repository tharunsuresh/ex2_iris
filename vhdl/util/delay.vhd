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

-- Delays a signal by DELAY_CLOCKS clock cycles
-- Based on https://stackoverflow.com/questions/45218347/how-to-delay-a-signal-for-several-clock-cycles-in-vhdl
entity n_delay is
generic (
    DELAY_CLOCKS : integer
);
port (
    clock   : in std_logic;
    reset_n : in std_logic;
    i       : in std_logic;
    o       : out std_logic
);
end entity n_delay;


architecture rtl of n_delay is
begin

    process (clock, reset_n)
        variable delay : std_logic_vector(DELAY_CLOCKS-1 downto 0);
    begin
        if reset_n = '0' then
            delay := (others => '0');
        elsif rising_edge(clock) then
            delay := i & delay(DELAY_CLOCKS-1 downto 1);
        end if;
        o <= delay(0);
    end process;

end architecture rtl;


library ieee;
use ieee.std_logic_1164.all;

-- When activated by holding `start` high for a singe clock cycle, waits
-- until `condition` is high, then outputs single-clock-cycle pulse on
-- `done`.
--
-- Designed to function as a compatibility layer between an architecture
-- that emits a start-process pulse and expects a process-done pulse, and
-- one that just holds process-done high indefinitely.
entity delay_until is
port (
    clock       : in std_logic;
    reset_n     : in std_logic;
    condition   : in std_logic;
    start       : in std_logic;
    done        : out std_logic
);
end entity delay_until;

architecture rtl of delay_until is
begin
    process (clock, reset_n)
        type state_t is (IDLE, WAITING);
        variable state : state_t;
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
                end if;
            when WAITING =>
                if condition = '1' then
                    state := IDLE;
                    done <= '1';
                end if;
            end case;
        end if;
    end process;
end architecture rtl;


library ieee;
use ieee.std_logic_1164.all;

-- Delays a signal by a single clock cycle
entity single_delay is
port (
    clock   : in std_logic;
    reset_n : in std_logic;
    i       : in std_logic;
    o       : out std_logic
);
end entity single_delay;

architecture rtl of single_delay is
begin
    
    process (clock, reset_n)
    begin
        if reset_n = '0' then
            o <= '0';
        elsif rising_edge(clock) then
            o <= i;
        end if;
    end process;

end architecture rtl;
