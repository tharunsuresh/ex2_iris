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
-- use work.vnir."/=";

--  BUG: 
--      When transmitting VNIR words, only transmits 159 words instead of 160. 
--      It reads the last one out of the fifo but doesnt send it out

entity imaging_buffer is
    port(
        --Control Signals
        clock               : in std_logic;
        reset_n             : in std_logic;

        --Rows of Data
        vnir_row            : in vnir.row_t;
        swir_pixel          : in swir_pixel_t;

        --Rows out
        fragment_out        : out row_fragment_t;
        fragment_type       : out sdram.row_type_t;
        row_request         : in std_logic;
        transmitting        : out std_logic;

        --Flag signals
        swir_pixel_ready    : in std_logic;
        vnir_row_ready      : in vnir.row_type_t
    );
end entity imaging_buffer;

architecture rtl of imaging_buffer is
    
    signal fifo_clear           : std_logic;

    --signals for the first stage of the vnir pipeline
    signal vnir_row_ready_i      : vnir.row_type_t;
    signal new_row_in            : std_logic;
    signal vnir_row_fragments    : vnir_row_fragment_a;

    signal row_buffer           : row_buffer_a;
    signal row_type_buffer      : row_type_buffer_a;


    --Signals for the first stage of the swir pipeline
    signal swir_bit_counter     : integer;
    signal swir_fragment        : row_fragment_t;

    --signals for the second stage of the vnir pipeline    
    -- signal row_type_buffer      : row_type_buffer_a;
    signal vnir_frag_counter    : natural range 0 to VNIR_FIFO_DEPTH;
    signal vnir_store_counter   : natural range 0 to NUM_VNIR_ROW_FIFO;
    signal num_store_vnir_rows  : natural range 0 to NUM_VNIR_ROW_FIFO;

    --Signal for the second stage of the swir pipeline
    signal swir_fragment_ready  : std_logic;
    signal swir_store_counter   : natural range 0 to NUM_SWIR_ROW_FIFO;
    signal num_store_swir_rows  : natural range 0 to NUM_SWIR_ROW_FIFO;

    --Signals for the third stage of the swir pipeline
    signal swir_link_rdreq      : std_logic_vector(0 to NUM_SWIR_ROW_FIFO-1);
    signal swir_link_wrreq      : std_logic_vector(0 to NUM_SWIR_ROW_FIFO-1);
    signal swir_fifo_empty      : std_logic_vector(0 to NUM_SWIR_ROW_FIFO-1);
    signal swir_fifo_full       : std_logic_vector(0 to NUM_SWIR_ROW_FIFO-1);
    signal swir_link_in         : swir_link_a;
    signal swir_link_out        : swir_link_a;

    --Signals for the fifos
    signal vnir_link_rdreq      : std_logic_vector(0 to NUM_VNIR_ROW_FIFO-1);
    signal vnir_link_wrreq      : std_logic_vector(0 to NUM_VNIR_ROW_FIFO-1);
    signal vnir_fifo_empty      : std_logic_vector(0 to NUM_VNIR_ROW_FIFO-1);
    signal vnir_link_in         : vnir_link_a;
    signal vnir_link_out        : vnir_link_a;

    signal transmitting_i       : std_logic;

    procedure assign_12_pixels (start_bit, start_pixel : in natural) is 
    begin

    end assign_12_pixels; 

begin

    VNIR_FIFO_GEN : for i in 0 to NUM_VNIR_ROW_FIFO-1 generate
        VNIR_FIFO : entity work.VNIR_ROW_FIFO port map (
            aclr    => fifo_clear,
            clock   => clock,
            data    => vnir_link_in(i),
            rdreq   => vnir_link_rdreq(i),
            wrreq   => vnir_link_wrreq(i),
            empty   => vnir_fifo_empty(i),
            q       => vnir_link_out(i)
        );
    end generate VNIR_FIFO_GEN;

    SWIR_FIFO_GEN : for i in 0 to NUM_SWIR_ROW_FIFO-1 generate
        SWIR_FIFO : entity work.SWIR_ROW_FIFO port map (
            aclr    => fifo_clear,
            clock   => clock,
            data    => swir_link_in(i),
            rdreq   => swir_link_rdreq(i),
            wrreq   => swir_link_wrreq(i),
            empty   => swir_fifo_empty(i),
            full    => swir_fifo_full(i),
            q       => swir_link_out(i)
        );
    end generate SWIR_FIFO_GEN;

    pipeline : process (reset_n, clock) is
        variable vnir_output_index  : integer := 0;
        variable swir_output_index  : integer := 0;
        
    begin
        if (reset_n = '0') then
            swir_bit_counter <= 0;
            swir_fragment <= (others => '0');

            swir_fragment_ready <= '0';
            swir_store_counter <= 0;

            swir_link_wrreq <= (others => '0');
            swir_link_rdreq <= (others => '0');
            swir_link_in <= (others => (others => '0'));
            
            --First stage resets
            vnir_row_ready_i <= vnir.ROW_NONE;
            new_row_in       <= '0';
            row_type_buffer  <= (others => '0');
            row_buffer       <= (others => (others => (others => '0')));

            --Second stage resets
            -- row_type_buffer <= (others => vnir.ROW_NONE);
            vnir_frag_counter <= 0;
            vnir_store_counter <= 0;

            --FIFO resets
            vnir_link_in <= (others => (others => '0'));
            vnir_link_rdreq <= (others => '0');
            vnir_link_wrreq <= (others => '0');
            
            vnir_output_index := 0;
            swir_output_index := 0;
            transmitting_i <= '0';

            fragment_out <= (others => '0');
            fragment_type <= sdram.ROW_NONE;
        
        elsif rising_edge(clock) then

            --The first stage of the vnir pipeline, converting a VNIR row to FIFO compatible words
            if (vnir_row_ready /= vnir.ROW_NONE) then    -- we have new row from VNIR subsystem

                new_row_in <= '1'; -- flag for next stage
                vnir_row_ready_i <= vnir_row_ready; -- register for storing row type

                -- 64 VNIR pixels (10 bits/pixel) can be put into 5 consecutive fifo words of 128 bits each.
                -- Since 128 is not a multiple of 10, some pixels need to be split up. 
                -- Every 5 words (128 bits/word * 5 words = 640 bits) we get to a multiple of 10, so we can put
                -- 64 complete pixels every 5 words.

                -- There are 32 of these 5-word groups in total (64 pixels/group * 32 groups = 2048 pixels total)            
                for five_word_group in 0 to 31 loop  
                    -- first word
                    for i in 0 to 11 loop    
                        vnir_row_fragments(5*five_word_group)((10*(i+1))-1 downto 10*i) <= std_logic_vector(vnir_row(64*five_word_group+i));
                    end loop;
                    for i in 120 to 127 loop -- final 8 bits of the word are the first 8 bits of the next (13th) pixel to make up the 128 bits
                        vnir_row_fragments(5*five_word_group)(i) <= vnir_row(64*five_word_group+12)(i-120);
                    end loop;
                    
                    -- second word
                    for i in 0 to 1 loop     -- the next word contains the last 2 pixels from the 13th pixel
                        vnir_row_fragments(5*five_word_group+1)(i) <= vnir_row(64*five_word_group+12)(8+i);  
                    end loop;
                    for i in 0 to 11 loop    -- 14th to 25th pixels
                        vnir_row_fragments(5*five_word_group+1)(((10*(i+1))+1) downto 10*i+2) <= std_logic_vector(vnir_row(64*five_word_group+13+i));
                    end loop;
                    for i in 122 to 127 loop -- first 6 bits of the 26th pixel
                        vnir_row_fragments(5*five_word_group+1)(i) <= vnir_row(64*five_word_group+25)(i-122);
                    end loop;
                
                    --third word 
                    for i in 0 to 3 loop     -- last 4 bits of the 26th pixel
                        vnir_row_fragments(5*five_word_group+2)(i) <= vnir_row(64*five_word_group+25)(6+i);  
                    end loop;
                    for i in 0 to 11 loop    -- 27th to 38th pixels
                        vnir_row_fragments(5*five_word_group+2)(((10*(i+1))+3) downto 10*i+4) <= std_logic_vector(vnir_row(64*five_word_group+26+i));
                    end loop;
                    for i in 124 to 127 loop -- 4 bits of the 39th pixel
                        vnir_row_fragments(5*five_word_group+2)(i) <= vnir_row(64*five_word_group+38)(i-124);
                    end loop;
                
                    -- fourth word
                    for i in 0 to 5 loop     -- rest of the 39th pixel
                        vnir_row_fragments(5*five_word_group+3)(i) <= vnir_row(64*five_word_group+38)(4+i);  
                    end loop;
                    for i in 0 to 11 loop    -- 40th to 51st pixels 
                        vnir_row_fragments(5*five_word_group+3)(((10*(i+1))+5) downto 10*i+6) <= std_logic_vector(vnir_row(64*five_word_group+39+i));
                    end loop;
                    for i in 126 to 127 loop -- 52nd pixel
                        vnir_row_fragments(5*five_word_group+3)(i) <= vnir_row(64*five_word_group+51)(i-126);
                    end loop;

                    --fifth word
                    for i in 0 to 7 loop     -- 52nd pixel
                        vnir_row_fragments(5*five_word_group+4)(i) <= vnir_row(64*five_word_group+51)(2+i);
                    end loop;
                    for i in 0 to 11 loop    -- 53rd to 64th pixels
                        vnir_row_fragments(5*five_word_group+4)((10*(i+1))+7 downto 10*i+8) <= std_logic_vector(vnir_row(64*five_word_group+52+i));
                    end loop;   
                end loop;     
            else 
                vnir_row_fragments <= (others => (others => 'X'));
                new_row_in <= '0';

            end if;

            -- VNIR stage 1.5: putting the fifo row fragments into the appropriate signal 
            if (new_row_in = '1') then
                case vnir_row_ready_i is 
                    when vnir.ROW_RED   => row_buffer(0) <= vnir_row_fragments;
                    when vnir.ROW_BLUE  => row_buffer(1) <= vnir_row_fragments;
                    when vnir.ROW_NIR   => row_buffer(2) <= vnir_row_fragments;
                    when others => --option filtered out in first stage, no need
                end case;
            end if;

            -- Second stage of the VNIR pipeline, storing data into the fifo chain

            -- TODO: USE A PROCEDURE TO AVOID DUPLICATING CODE
            -- first implement fifo for red row normally

            

            -- row_type_buffer(0)   <= '1'; --enable after storing into fifo
            -- row_type_buffer(1)   <= '1';
            -- row_type_buffer(2)   <= '1';


            if (vnir_frag_counter < VNIR_FIFO_DEPTH and vnir_row_ready_i /= vnir.ROW_NONE) then
                vnir_link_in(vnir_store_counter) <= vnir_row_fragments(vnir_frag_counter);
                vnir_link_wrreq(vnir_store_counter) <= '1';
                vnir_frag_counter <= vnir_frag_counter + 1;

                --If it's the last word getting stored, adding the type to the type buffer
                if (vnir_frag_counter = VNIR_FIFO_DEPTH-1) then
                    row_type_buffer(vnir_store_counter) <= vnir_row_ready_i;
                    vnir_store_counter <= vnir_store_counter + 1;
                    num_store_vnir_rows <= num_store_vnir_rows + 1;
                end if;

            -- else
            --     vnir_frag_counter <= 0;
            --     vnir_link_in <= (others => (others => '0'));
            --     vnir_link_wrreq <= (others => '0');
            -- end if;
        
            -- --The first stage of the swir_pipeline, accumulating pixels to fill a word
            -- if (swir_pixel_ready = '1') then
        
            --     if (swir_bit_counter = FIFO_WORD_LENGTH) then
            --         swir_fragment_ready <= '1';
            --         swir_bit_counter <= 0;
            --     else
            --         swir_fragment(swir_bit_counter + SWIR_PIXEL_BITS - 1 downto swir_bit_counter) <= std_logic_vector(swir_pixel);
            --         swir_bit_counter <= swir_bit_counter + SWIR_PIXEL_BITS;
            --     end if;
            -- end if;
        
            -- --The second stage of the swir pipeline, putting the fragment into the fifo chain
            -- if (swir_fragment_ready = '1') then
            --     swir_link_wrreq(swir_store_counter) <= '1';
            --     swir_link_in(swir_store_counter) <= swir_fragment;
            --     swir_fragment_ready <= '0';
            -- else
            --     swir_link_wrreq <= (others => '0');
            --     swir_link_in <= (others => (others => '0'));
            -- end if;
        
            -- --Checking to see if a fifo is full and incrementing the store counter
            -- if (swir_fifo_full(swir_store_counter) = '1') then
            --     swir_store_counter <= swir_store_counter + 1;
            --     num_store_swir_rows <= num_store_swir_rows + 1;
            -- end if;
            
            -- --The final stage
            -- vnir_output_index := vnir_store_counter - num_store_vnir_rows;
            -- swir_output_index := swir_store_counter - num_store_swir_rows;
        
            -- if (row_request = '1') then
            --     transmitting_i <= '1';
            -- end if;
        
            -- if (transmitting_i = '1') then
            --     --These first two branches set the output to the correct fifo
            --     if (num_store_vnir_rows >= num_store_swir_rows and num_store_vnir_rows /= 0 and vnir_fifo_empty(vnir_output_index) = '0') then
            --         vnir_link_rdreq(vnir_output_index) <= '1';
            --         fragment_out <= vnir_link_out(vnir_output_index);
            --         fragment_type <= sdram.sdram_type(row_type_buffer(vnir_output_index));
        
            --     elsif (num_store_swir_rows > num_store_vnir_rows and swir_fifo_empty(swir_output_index) = '0') then
            --         swir_link_rdreq(swir_output_index) <= '1';
            --         fragment_out <= swir_link_out(swir_output_index);
            --         fragment_type <= sdram.ROW_SWIR;
        
            --     --These next two branches reset the output and increment the correct buffer
            --     elsif (vnir_fifo_empty(vnir_output_index) = '1') then
            --         vnir_link_rdreq(vnir_output_index) <= '0';
            --         num_store_vnir_rows <= num_store_vnir_rows - 1;
            --         transmitting_i <= '0';
        
            --     elsif (swir_fifo_empty(swir_output_index) = '1') then
            --         swir_link_rdreq(swir_output_index) <= '0';
            --         num_store_swir_rows <= num_store_swir_rows - 1;
            --         transmitting_i <= '0';
            --     end if;
            -- else
            --     fragment_out <= (others => '0');
            --     fragment_type <= sdram.ROW_NONE;
            -- end if;
        end if;
    end process pipeline;

    

    fifo_clear <= '1' when reset_n = '0' else '0';
    transmitting <= transmitting_i;
end architecture;