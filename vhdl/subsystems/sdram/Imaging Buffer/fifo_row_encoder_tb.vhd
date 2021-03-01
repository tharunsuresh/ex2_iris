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

library work;
use work.img_buffer_pkg.all;
use work.swir_types.all;
use work.sdram;
use work.fpga.all;

use work.vnir;
use work.vnir."/=";

entity fifo_row_encoder_tb is
end entity fifo_row_encoder_tb;

architecture rtl of fifo_row_encoder_tb is
    
    --Clock frequency is 20 MHz
    constant clock_frequency    : integer := 20000000;
    constant clock_period       : time := 1000 ms / clock_frequency;
    
    --Control inputs
    signal clock                : std_logic := '1';
    signal reset_n              : std_logic := '0';

    signal vnir_row             : vnir.row_t := (others => "1111111111");
    signal vnir_row_ready       : vnir.row_type_t;
    signal vnir_row_fragments    : vnir_row_fragment_a;

begin
    clock <= not clock after clock_period / 2;

    inst: entity work.fifo_row_encoder port map(
        clock           => clock,
        reset_n         => reset_n,
        vnir_row        => vnir_row,
        vnir_row_ready  => vnir_row_ready,
        vnir_row_fragments => vnir_row_fragments
        );

    reset_process: process
    begin
        reset_n <= '0';
        wait for clock_period*2; 
        reset_n <= '1';
        wait;
    end process reset_process;

    process is 
    begin

        vnir_row_ready <= vnir.ROW_NONE;
        wait for clock_period*5;

        vnir_row_ready <= vnir.ROW_RED;
        for i in 0 to vnir.ROW_WIDTH-1 loop
            vnir_row(i) <= to_unsigned(i, vnir.PIXEL_BITS);
        end loop;
        wait for clock_period;
        
        vnir_row_ready <= vnir.ROW_NONE;
        wait; 

    end process;
end architecture;
