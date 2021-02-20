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
use work.fpga_types.all;

use work.vnir;
use work.vnir."/=";

entity fifo_array_encoder_tb is
end entity fifo_array_encoder_tb;

architecture rtl of fifo_array_encoder_tb is

    signal clock                : std_logic := '0'; 
    signal reset_n              : std_logic := '0'; 

    signal vnir_row             : vnir.row_t := (others => "1111111111");
    signal vnir_row_fragment    : row_fragment_t;
    -- signal num_bit              : natural;
    -- signal num_pixel            : natural;
 
begin

    inst: entity work.fifo_array_encoder port map(
        clock           => clock,
        reset_n         => reset_n,
        vnir_row        => vnir_row,
        -- num_bit         => num_bit,
        -- num_pixel       => num_pixel,
        vnir_row_fragment => vnir_row_fragment
        );

    reset_process: process
    begin
        reset_n <= '0';
        wait for 50 ns; 
        reset_n <= '1';
        wait;
    end process reset_process;

    clock <= NOT clock after 10 ns; 
    -- num_bit     <= 0;
    -- num_pixel   <= 0;

    process is 
    begin

        for i in 0 to vnir.ROW_WIDTH-1 loop
            vnir_row(i) <= to_unsigned(i, vnir.PIXEL_BITS);
        end loop;
        
        wait; 

    end process;
end architecture;
