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
    
    signal vnir_row             : vnir.row_t := (others => "1111111111");
    --signal fifo_word            : vnir_fifo_row;
    --signal fifo_array           : vnir_fifo_array;
    signal vnir_row_fragment   : row_fragment_t;
    signal vnir_frag_counter   : integer := 0;

begin

    inst: entity work.fifo_array_encoder port map(
        vnir_row        => vnir_row,
        --fifo_array      => fifo_array
        vnir_row_fragment => vnir_row_fragment,
        vnir_frag_counter => vnir_frag_counter
        );

    process is 
    begin

        for i in 0 to 2047 loop
            vnir_row(i) <= to_unsigned(i, 10);
        end loop;
        
        vnir_frag_counter <= 0;

        wait; 

    end process;
end architecture;
