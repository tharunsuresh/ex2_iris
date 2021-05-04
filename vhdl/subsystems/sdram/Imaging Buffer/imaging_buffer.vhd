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

-- possible bug: what happens if you get row_request at the same clock cycle as when you finish transmitting?


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
    signal fifo_write           : row_type_tracker_a;
    signal row_type_stored      : row_type_tracker_a;

    --Signals for the first stage of the swir pipeline
    signal swir_bit_counter     : integer;
    signal swir_fragment        : row_fragment_t;

    --signals for the second stage of the vnir pipeline    
    signal vnir_frag_counter    : frag_count_a;
    signal vnir_store_counter   : natural range 0 to NUM_VNIR_ROW_FIFO;
    signal num_store_vnir_rows  : natural range 0 to NUM_VNIR_ROW_FIFO;

    --Signal for the second stage of the swir pipeline
    signal swir_fragment_ready  : std_logic;
    signal swir_fifo_stored   : std_logic;

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
    signal swir_out_counter     : natural range 0 to SWIR_FIFO_DEPTH+1;
    signal vnir_out_counter     : natural range 0 to VNIR_FIFO_DEPTH+1;

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
        
    begin
        if (reset_n = '0') then
            
            -- SWIR
            swir_bit_counter <= 0;
            swir_fragment <= (others => '0');

            swir_fragment_ready <= '0';
            swir_fifo_stored <= '0';

            swir_link_wrreq <= (others => '0');
            swir_link_rdreq <= (others => '0');
            swir_link_in <= (others => (others => '0'));
            
            -- VNIR 
            -- First stage resets
            vnir_row_ready_i <= vnir.ROW_NONE;
            new_row_in       <= '0';
            row_type_stored  <= (others => '0');
            row_buffer       <= (others => (others => (others => '0')));

            --Second stage resets
            fifo_write <= (others => '0');
            vnir_frag_counter <= (others => 0);
            vnir_store_counter <= 0;

            --FIFO resets
            vnir_link_in <= (others => (others => '0'));
            vnir_link_rdreq <= (others => '0');
            vnir_link_wrreq <= (others => '0');
            
            transmitting_i <= '0';

            -- Outputs 
            transmitting <= '0';
            swir_out_counter <= 0;
            vnir_out_counter <= 0;
        
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
                    for i in 0 to 11 loop    -- put 12 full pixels in the first fifo word
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
                vnir_row_ready_i <= vnir.ROW_NONE;
            end if;

            -- VNIR stage 1.5: putting the fifo row fragments into the appropriate signal 
            if (new_row_in = '1') then
                case vnir_row_ready_i is 
                    when vnir.ROW_RED   => 
                        row_buffer(0) <= vnir_row_fragments;   -- store fragments in temp registers
                        fifo_write(0) <= '1';                   -- start reading into fifo
                    when vnir.ROW_BLUE  => 
                        row_buffer(1) <= vnir_row_fragments;
                        fifo_write(1) <= '1';
                    when vnir.ROW_NIR   => 
                        row_buffer(2) <= vnir_row_fragments;
                        fifo_write(2) <= '1';
                    when others => 
                        report "Invalid new row input to imaging buffer" severity failure;
                end case;
            end if;

            -- Second stage of the VNIR pipeline, storing data into the fifo chain
            for i in 0 to NUM_VNIR_ROW_FIFO-1 loop  -- three second stages in parallel; one for each row fifo
                if (fifo_write(i) = '1') then
                    vnir_link_in(i) <= row_buffer(i)(vnir_frag_counter(i));
                    vnir_link_wrreq(i) <= '1';
                    vnir_frag_counter(i) <= vnir_frag_counter(i) + 1;
        
                    --If it's the last word getting stored, adding the type to the type buffer
                    if (vnir_frag_counter(i) = VNIR_FIFO_DEPTH-1) then
                        fifo_write(i) <= '0';       -- finished writing to fifo 
                        row_type_stored(i) <= '1';  -- stored, can be transmitted now
                    end if;
                else
                    vnir_frag_counter(i) <= 0;      -- finished writing to fifo
                    vnir_link_in(i) <= (others => '0');
                    vnir_link_wrreq(i) <= '0'; 
                end if;
            end loop;

            --The first stage of the swir_pipeline, accumulating pixels to fill a word
            if (swir_pixel_ready = '1') then 
                swir_fragment(swir_bit_counter + SWIR_PIXEL_BITS - 1 downto swir_bit_counter) <= std_logic_vector(swir_pixel);
                swir_bit_counter <= swir_bit_counter + SWIR_PIXEL_BITS;
            end if;
        
            --The second stage of the swir pipeline, putting the fragment into the fifo chain
            if (swir_bit_counter = FIFO_WORD_LENGTH) then 
                swir_link_wrreq(0) <= '1';
                swir_link_in(0) <= swir_fragment;
                swir_bit_counter <= 0;
            else
                swir_link_wrreq <= (others => '0');
                swir_link_in <= (others => (others => '0'));
            end if;
        
            --Checking to see if a fifo is full and enabling the flag to send swir fifo 
            if (swir_fifo_full(0) = '1') then
                swir_fifo_stored <= '1';
            end if;
            
            --The final stage
            if (row_request = '1') then
                transmitting_i <= '1';
            end if;
            
            if (transmitting_i = '1') then
                if (swir_fifo_stored /= '0') then
                    if swir_fifo_empty(0) = '0' then  -- while the swir fifo is not empty
                        swir_link_rdreq(0) <= '1';    -- read it
                        fragment_out <= swir_link_out(0);   
                        fragment_type <= sdram.ROW_SWIR;
                        transmitting <= '1';
                        swir_out_counter <= swir_out_counter + 1;
                    elsif swir_out_counter = SWIR_FIFO_DEPTH+1 then -- if last fragment in fifo
                        fragment_out <= swir_link_out(0);
                        swir_out_counter <= 0;
                    else 
                        swir_link_rdreq(0) <= '0';
                        swir_fifo_stored <= '0';
                        fragment_out <= (others => 'X');
                        fragment_type <= sdram.ROW_NONE;
                        transmitting <= '0';
                        transmitting_i <= '0';
                    end if;
                elsif (row_type_stored(0) = '1') then
                    if vnir_fifo_empty(0) = '0' then  -- while the red fifo is not empty
                        vnir_link_rdreq(0) <= '1';    -- read it 
                        fragment_out <= vnir_link_out(0); 
                        fragment_type <= sdram.ROW_RED;
                        transmitting <= '1';
                        vnir_out_counter <= vnir_out_counter + 1;
                    elsif vnir_out_counter = VNIR_FIFO_DEPTH+1 then -- if last fragment in fifo
                        fragment_out <= vnir_link_out(0);
                        vnir_out_counter <= 0;
                    else 
                        row_type_stored(0) <= '0';
                        vnir_link_rdreq(0) <= '0';
                        fragment_out <= (others => 'X');
                        fragment_type <= sdram.ROW_NONE;
                        transmitting <= '0';
                        transmitting_i <= '0';
                    end if;
                elsif (row_type_stored(1) = '1') then
                    if vnir_fifo_empty(1) = '0' then
                        vnir_link_rdreq(1) <= '1';
                        fragment_out <= vnir_link_out(1);
                        fragment_type <= sdram.ROW_BLUE;
                        transmitting <= '1';
                        vnir_out_counter <= vnir_out_counter + 1;
                    elsif vnir_out_counter = VNIR_FIFO_DEPTH+1 then -- if last fragment in fifo
                        fragment_out <= vnir_link_out(1);
                        vnir_out_counter <= 0;
                    else 
                        row_type_stored(1) <= '0';
                        vnir_link_rdreq(1) <= '0';
                        fragment_out <= (others => 'X');
                        fragment_type <= sdram.ROW_NONE;
                        transmitting <= '0';
                        transmitting_i <= '0';
                    end if;
                elsif (row_type_stored(2) = '1') then
                    if vnir_fifo_empty(2) = '0' then
                        vnir_link_rdreq(2) <= '1';
                        fragment_out <= vnir_link_out(2);
                        fragment_type <= sdram.ROW_NIR;
                        transmitting <= '1';
                        vnir_out_counter <= vnir_out_counter + 1;
                    elsif vnir_out_counter = VNIR_FIFO_DEPTH+1 then -- if last fragment in fifo
                        fragment_out <= vnir_link_out(2);
                        vnir_out_counter <= 0;
                    else 
                        row_type_stored(2) <= '0';
                        vnir_link_rdreq(2) <= '0';
                        fragment_out <= (others => 'X');
                        fragment_type <= sdram.ROW_NONE;
                        transmitting <= '0';
                        transmitting_i <= '0';
                    end if;
                else 
                    fragment_out <= (others => 'X');
                    fragment_type <= sdram.ROW_NONE;
                    transmitting <= '0';
                end if;
            else
                fragment_out <= (others => 'X');
                fragment_type <= sdram.ROW_NONE;
                transmitting <= '0';
            end if;
        end if;
    end process pipeline;

    fifo_clear <= '1' when reset_n = '0' else '0';

end architecture;