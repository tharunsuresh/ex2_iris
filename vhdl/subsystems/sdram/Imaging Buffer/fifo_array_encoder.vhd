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
use work.vnir;

entity fifo_array_encoder is
    port(
        vnir_row            : in vnir.row_t;
        vnir_frag_counter   : in integer := 0;
        vnir_row_fragment   : out row_fragment_t
    );
end entity fifo_array_encoder;

architecture rtl of fifo_array_encoder is
    signal fifo_array: vnir_fifo_array;
begin

    --takes the entire input vnir row and converts to fifo rows of appropriate witdth and depth
    array_generate: for j in 0 to VNIR_FIFO_DEPTH-1 generate
        row_generate: for i in 0 to pixels_per_row-1 generate
            fifo_array(j)(i) <= std_logic_vector(vnir_row(i+j*pixels_per_row));
        end generate row_generate;
    end generate array_generate;

    --convert the requested row into one std_logic_vector row suitable for input into fifo
    fifo_row_generate: for i in 0 to pixels_per_row-1 generate
        vnir_row_fragment((vnir.PIXEL_BITS*(i+1))-1 downto vnir.PIXEL_BITS*i) <= fifo_array(vnir_frag_counter)(i);
    end generate fifo_row_generate;

--TODO: MAKE SURE ORDER OF THE VNIR ROW FRAGMENT AND FIFO ARRAY IS MSB->LSB or LSB->MSB. CHECK NASH's version for confirmation
    

end architecture;