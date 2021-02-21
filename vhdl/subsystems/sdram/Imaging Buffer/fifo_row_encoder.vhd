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

-- this file puts the VNIR row into fifo words that are 128 bits wide
-- the general case does not synthesize with Quartus, so this is a specific & simplified version for 
-- FIFO_WORD_LENGTH = 128, vnir.PIXEL_BITS = 10 
-- WARNING: Breaks if any of the assumptions are changed.

entity fifo_row_encoder is
    port(
        clock               : in std_logic;
        reset_n             : in std_logic;
        vnir_row            : in vnir.row_t;
        vnir_row_fragment   : out row_fragment_t
    );
end entity fifo_row_encoder;

architecture rtl of fifo_row_encoder is

    signal start_pixel    : natural := 0;
    signal start_bit      : natural := 0;

begin

-- NEXT STEP: MERGE IMAGING BUFFER AND THIS FILE. MAKE THEM WORK TOGETHER
-- IDEA: when vnir_row comes in, register it with an internal variable
-- when final word is sent to imaging buffer, then register the next row
    
    proc_row_collect: process (reset_n, clock) is
    begin
        if reset_n = '0' then
            vnir_row_fragment <= (others => '0');

        elsif rising_edge(clock) then

            -- if the fifo word does not carry any remaining bits from previous pixels
            if start_bit = 0 then        
                for i in 0 to 11 loop    -- the first 120 bits are put into the fifo word (12 complete pixels)
                    vnir_row_fragment((10*(i+1))-1 downto 10*i) <= std_logic_vector(vnir_row(start_pixel+i));
                end loop;
                for i in 120 to 127 loop -- then the final 8 bits from the next (13th) pixel to make up the 128 bits
                    vnir_row_fragment(i) <= vnir_row(start_pixel+12)(i-120);
                end loop;

            -- if the start bit is 2 (8 bits remaining from the previous fifo word)  
            elsif start_bit = 2 then         
                for i in 0 to 7 loop     -- those 8 bits are put first into the fifo word
                    vnir_row_fragment(i) <= vnir_row(start_pixel)(start_bit+i);
                end loop;
                for i in 0 to 11 loop    -- then the final 120 bits are made up of 12 complete pixels
                    vnir_row_fragment((10*(i+1))+7 downto 10*i+8) <= std_logic_vector(vnir_row(start_pixel+i+1));
                end loop;          
            
            -- the last three cases are similar but the loop boundaries differ. 
            -- Quartus doesn't synthesize with dynamic loop lengths 
            elsif start_bit = 4 then 
                for i in 0 to 5 loop
                    vnir_row_fragment(i) <= vnir_row(start_pixel)(start_bit+i);  
                end loop;
                for i in 0 to 11 loop
                    vnir_row_fragment(((10*(i+1))+5) downto 10*i+6) <= std_logic_vector(vnir_row(start_pixel+i+1));
                end loop;
                for i in 126 to 127 loop
                    vnir_row_fragment(i) <= vnir_row(start_pixel+13)(i-126);
                end loop;

            elsif start_bit = 6 then 
                for i in 0 to 3 loop
                    vnir_row_fragment(i) <= vnir_row(start_pixel)(start_bit+i);  
                end loop;
                for i in 0 to 11 loop
                    vnir_row_fragment(((10*(i+1))+3) downto 10*i+4) <= std_logic_vector(vnir_row(start_pixel+i+1));
                end loop;
                for i in 124 to 127 loop
                    vnir_row_fragment(i) <= vnir_row(start_pixel+13)(i-124);
                end loop;

            elsif start_bit = 8 then 
                for i in 0 to 1 loop
                    vnir_row_fragment(i) <= vnir_row(start_pixel)(start_bit+i);  
                end loop;
                for i in 0 to 11 loop
                    vnir_row_fragment(((10*(i+1))+1) downto 10*i+2) <= std_logic_vector(vnir_row(start_pixel+i+1));
                end loop;
                for i in 122 to 127 loop
                    vnir_row_fragment(i) <= vnir_row(start_pixel+13)(i-122);
                end loop;

            else
                vnir_row_fragment <= (others => 'X'); -- invalid input
            end if;
            
        end if;
    end process proc_row_collect;
    
    proc_index: process (reset_n, clock) is
        --Variables used to help calculate the pixels and bit indices
        variable pixel_num      : natural := 0;
        variable pixel_bit      : natural := 0;        
    begin
        if reset_n = '0' then
            start_pixel <= 0;
            start_bit   <= 0;

        elsif rising_edge(clock) then            
            for i in 0 to FIFO_WORD_LENGTH-1 loop
                if (pixel_bit = 9) then
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

            start_pixel   <= pixel_num;
            start_bit     <= pixel_bit;

        end if;    
    end process proc_index;


end architecture;