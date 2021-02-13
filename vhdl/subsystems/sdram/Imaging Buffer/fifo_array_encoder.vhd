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
        clock               : in std_logic;
        --reset_n             : in std_logic;
        vnir_row            : in vnir.row_t;
        num_bit             : in natural;
        num_pixel           : in natural;
        vnir_row_fragment   : out row_fragment_t
    );
end entity fifo_array_encoder;

architecture rtl of fifo_array_encoder is
    signal final_pixel : natural := 0;
    signal final_bit   : natural := 0;


begin

    process (clock) is
            --Variables used to help calculate the pixels that need to be split up to store the data in the FIFO
    variable pixel_num      : natural := 0;
    variable pixel_bit      : natural := 0;        


    begin
        --for frag_array_index in 0 to VNIR_FIFO_DEPTH-1 loop

        if rising_edge(clock) then
            pixel_num := num_pixel;
            pixel_bit := num_bit;
            
            for i in 0 to FIFO_WORD_LENGTH-1 loop
                vnir_row_fragment(i) <= vnir_row(pixel_num)(pixel_bit);

                if (pixel_bit = vnir.PIXEL_BITS-1) then
                    pixel_bit := 0;
                    if (pixel_num = vnir.ROW_WIDTH-1) then
                        pixel_num := 0;
                        --set flag to end loop
                    else 
                        pixel_num := pixel_num + 1;
                    end if;
                else
                    pixel_bit := pixel_bit + 1;
                end if;
            end loop;

            final_pixel <= pixel_num;
            final_bit  <= pixel_bit;        

        end if;    

        --Conditional logic for incrementing pixel and but info



        --end loop;
    end process;

end architecture;