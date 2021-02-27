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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.vnir_base.all;
use work.lvds_decoder_pkg.all;


entity lvds_decoder_out is
generic (
    FRAGMENT_WIDTH  : integer;
    PIXEL_BITS      : integer
);
port (
    clock               : in std_logic;
    reset_n             : in std_logic;
    
    data_in_available   : in std_logic;
    from_fifo           : in std_logic_vector;
    
    align_done          : out std_logic;
    
    fragment            : out pixel_vector_t;
    fragment_control    : out control_t;
    fragment_available  : out std_logic
);
end entity lvds_decoder_out;


architecture rtl of lvds_decoder_out is
    constant FRAGMENT_BITS : integer := FRAGMENT_WIDTH * PIXEL_BITS;

    signal from_fifo_is_aligned : std_logic;
    signal from_fifo_control : control_t;
    signal from_fifo_fragment : pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
begin
    
    from_fifo_is_aligned <= from_fifo(FRAGMENT_BITS + PIXEL_BITS);
    from_fifo_control <= to_control(from_fifo(
        FRAGMENT_BITS + PIXEL_BITS - 1 downto FRAGMENT_BITS
    ));
    from_fifo_fragment <= unflatten_to_fragment(from_fifo(
        FRAGMENT_BITS - 1 downto 0
    ), PIXEL_BITS);

    fsm : process (reset_n, clock)
        type state_t is (ALIGNED, NONALIGNED);
        variable state : state_t;
    begin
        if reset_n = '0' then
            align_done <= '0';
            fragment_available <= '0';
            state := NONALIGNED;
        elsif rising_edge(clock) then
            align_done <= '0';
            fragment_available <= '0';

            case state is
            when NONALIGNED =>
                if from_fifo_is_aligned = '1' then
                    state := ALIGNED;
                    align_done <= '1';
                end if;
            when ALIGNED =>
                if from_fifo_is_aligned /= '1' then
                    state := NONALIGNED;
                end if;
            end case;

            if state = ALIGNED then
                if data_in_available = '1' then
                    fragment_available <= '1';
                    fragment_control <= from_fifo_control;
                    fragment <= from_fifo_fragment;
                end if;
            end if;

        end if;
    end process fsm;

end architecture rtl;