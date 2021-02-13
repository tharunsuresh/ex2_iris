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
        --clock               : in std_logic;
        --reset_n             : in std_logic;
        vnir_row            : in vnir.row_t;
        num_bit             : in natural;
        num_pixel           : in natural;
        vnir_row_fragment   : out row_fragment_t
    );
end entity fifo_array_encoder;

architecture rtl of fifo_array_encoder is
    
begin

    initial_start_pixel <= num_pixel;
    middle_start_pixel  <= num_pixel + 1;
    final_start_pixel   <= num_pixel + PIXELS_PER_ROW + 1;

    initial_start_bit   <= num_bit;
    final_end_bit       <= vnir.PIXEL_BITS ;    

    process is
    begin
        if num_bit = 0 then
            for 
                vnir_row_fragment( downto )
            end loop;


        elsif num_bit = 2 or num_bit = 4 or num_bit = 6 then



        elsif num_bit = 8 then



        else
            vnir_row_fragment <= (others => 'X'); --invalid input
        end if;

    end process;



end architecture;