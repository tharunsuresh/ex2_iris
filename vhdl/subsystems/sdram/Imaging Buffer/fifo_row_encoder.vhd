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
use work.vnir."/=";

-- fifo_row_encoder puts the large VNIR row into fifo words that are 128 bits wide
-- the general case does not synthesize with Quartus, so this is a specific & simplified version for 
-- FIFO_WORD_LENGTH = 128, vnir.PIXEL_BITS = 10 that exploits symmetries in this case 
-- WARNING: Breaks if any of the assumptions are changed.          

entity fifo_row_encoder is
    port(
        clock               : in std_logic;
        reset_n             : in std_logic;
        vnir_row            : in vnir.row_t;
        vnir_row_ready      : in vnir.row_type_t;
        vnir_row_fragments  : out vnir_row_fragment_a
    );
end entity fifo_row_encoder;

architecture rtl of fifo_row_encoder is
begin
    proc_row_collect: process (reset_n, clock) is    
    begin
        if reset_n = '0' then
            vnir_row_fragments <= (others => (others => 'X'));

        elsif rising_edge(clock) then
            if (vnir_row_ready /= vnir.ROW_NONE) then    

                -- 64 pixels can be put into 5 consecutive fifo words. There are 32 of these groups in total (32*64 = 2048)            
                for five_row_group in 0 to 31 loop  
                    -- first word
                    for i in 0 to 11 loop    -- the first 120 bits are put into the fifo word (12 complete pixels)
                        vnir_row_fragments(5*five_row_group)((10*(i+1))-1 downto 10*i) <= std_logic_vector(vnir_row(64*five_row_group+i));
                    end loop;
                    for i in 120 to 127 loop -- final 8 bits of the word are the first 8 bits of the next (13th) pixel to make up the 128 bits
                        vnir_row_fragments(5*five_row_group)(i) <= vnir_row(64*five_row_group+12)(i-120);
                    end loop;
                    
                    -- second word
                    for i in 0 to 1 loop     -- the next word contains the last 2 pixels from the 13th pixel
                        vnir_row_fragments(5*five_row_group+1)(i) <= vnir_row(64*five_row_group+12)(8+i);  
                    end loop;
                    for i in 0 to 11 loop    -- 14th to 25th pixels
                        vnir_row_fragments(5*five_row_group+1)(((10*(i+1))+1) downto 10*i+2) <= std_logic_vector(vnir_row(64*five_row_group+13+i));
                    end loop;
                    for i in 122 to 127 loop -- first 6 bits of the 26th pixel
                        vnir_row_fragments(5*five_row_group+1)(i) <= vnir_row(64*five_row_group+25)(i-122);
                    end loop;
                
                    --third word 
                    for i in 0 to 3 loop     -- last 4 bits of the 26th pixel
                        vnir_row_fragments(5*five_row_group+2)(i) <= vnir_row(64*five_row_group+25)(6+i);  
                    end loop;
                    for i in 0 to 11 loop    -- 27th to 38th pixels
                        vnir_row_fragments(5*five_row_group+2)(((10*(i+1))+3) downto 10*i+4) <= std_logic_vector(vnir_row(64*five_row_group+26+i));
                    end loop;
                    for i in 124 to 127 loop -- 4 bits of the 39th pixel
                        vnir_row_fragments(5*five_row_group+2)(i) <= vnir_row(64*five_row_group+38)(i-124);
                    end loop;
                
                    -- fourth word
                    for i in 0 to 5 loop     -- rest of the 39th pixel
                        vnir_row_fragments(5*five_row_group+3)(i) <= vnir_row(64*five_row_group+38)(4+i);  
                    end loop;
                    for i in 0 to 11 loop    -- 40th to 51st pixels 
                        vnir_row_fragments(5*five_row_group+3)(((10*(i+1))+5) downto 10*i+6) <= std_logic_vector(vnir_row(64*five_row_group+39+i));
                    end loop;
                    for i in 126 to 127 loop -- 52nd pixel
                        vnir_row_fragments(5*five_row_group+3)(i) <= vnir_row(64*five_row_group+51)(i-126);
                    end loop;

                    --fifth word
                    for i in 0 to 7 loop     -- 52nd pixel
                        vnir_row_fragments(5*five_row_group+4)(i) <= vnir_row(64*five_row_group+51)(2+i);
                    end loop;
                    for i in 0 to 11 loop    -- 53rd to 64th pixels
                        vnir_row_fragments(5*five_row_group+4)((10*(i+1))+7 downto 10*i+8) <= std_logic_vector(vnir_row(64*five_row_group+52+i));
                    end loop;   
                end loop;
            else 
                vnir_row_fragments <= (others => (others => 'X'));
            end if;
        end if;
    end process proc_row_collect;

end architecture;