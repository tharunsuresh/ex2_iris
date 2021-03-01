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
    --SWIR words are 64 bits (4 pixel per word) 
    --VNIR words are 160 bits (16 pixels per word)

    signal fifo_clear           : std_logic;

    --signals for the first stage of the vnir pipeline
    signal vnir_row_ready_i     : vnir.row_type_t;
    signal vnir_row_fragment    : row_fragment_t;

    --Signals for the first stage of the swir pipeline
    signal swir_bit_counter     : integer;
    signal swir_fragment        : row_fragment_t;

    --signals for the second stage of the vnir pipeline
    signal vnir_fragment_in     : std_logic;
    signal row_type_buffer      : row_type_buffer_a;
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
begin
    --Generating a chain of FIFOs for both the vnir & swir rows, 
    --each FIFO capable of holding 10 rows of each type, words of 128 bits each
    --NOTE: The ip doesn't allow for choosing a FIFO with a depth of 160 words, so
    --the almost full signal is used in the full signal's place
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
    
    -- row_encoder_inst: entity work.fifo_row_encoder port map(
    --     clock           => clock,
    --     reset_n         => reset_n,
    --     vnir_row        => vnir_row,
    --     vnir_row_ready  => vnir_row_ready,
    --     fragment_out    => vnir_fragment_in,
    --     vnir_row_fragment => vnir_row_fragment
    --     );

    -- pipeline : process (reset_n, clock) is
    --     variable vnir_output_index  : integer := 0;
    --     variable swir_output_index  : integer := 0;
        
    -- begin
    --     if (reset_n = '0') then
    --         swir_bit_counter <= 0;
    --         swir_fragment <= (others => '0');

    --         swir_fragment_ready <= '0';
    --         swir_store_counter <= 0;

    --         swir_link_wrreq <= (others => '0');
    --         swir_link_rdreq <= (others => '0');
    --         swir_link_in <= (others => (others => '0'));
            
    --         --First stage resets
    --         vnir_row_ready_i <= vnir.ROW_NONE;

    --         --Second stage resets
    --         row_type_buffer <= (others => vnir.ROW_NONE);
    --         vnir_frag_counter <= 0;
    --         vnir_store_counter <= 0;

    --         --FIFO resets
    --         vnir_link_in <= (others => (others => '0'));
    --         vnir_link_rdreq <= (others => '0');
    --         vnir_link_wrreq <= (others => '0');
            
    --         vnir_output_index := 0;
    --         swir_output_index := 0;
    --         transmitting_i <= '0';

    --         fragment_out <= (others => '0');
    --         fragment_type <= sdram.ROW_NONE;
        
    --     elsif rising_edge(clock) then

    --         --The first stage of the vnir pipeline, converting data taken from the vnir system into word sizes 
    --         --compatible with fifo width -> this is done by fifo_row_encoder.vhd
    --         if (vnir_row_ready /= vnir.ROW_NONE) then
    --             vnir_row_ready_i <= vnir_row_ready;
    --         end if;

    --         --Second stage of the VNIR pipeline, storing data into the fifo chain
    --         if (vnir_frag_counter < VNIR_FIFO_DEPTH and vnir_fragment_in = '1') then
    --             vnir_link_in(vnir_store_counter) <= vnir_row_fragment;
    --             vnir_link_wrreq(vnir_store_counter) <= '1';
    --             vnir_frag_counter <= vnir_frag_counter + 1;

    --             --If it's the last word getting stored, adding the type to the type buffer
    --             if (vnir_frag_counter = VNIR_FIFO_DEPTH-1) then
    --                 row_type_buffer(vnir_store_counter) <= vnir_row_ready_i;
    --                 vnir_store_counter <= vnir_store_counter + 1;
    --                 num_store_vnir_rows <= num_store_vnir_rows + 1;
    --             end if;

    --         else
    --             vnir_frag_counter <= 0;
    --             vnir_link_in <= (others => (others => '0'));
    --             vnir_link_wrreq <= (others => '0');
    --         end if;
        
    --         --The first stage of the swir_pipeline, accumulating pixels to fill a word
    --         if (swir_pixel_ready = '1') then
        
    --             if (swir_bit_counter = FIFO_WORD_LENGTH) then
    --                 swir_fragment_ready <= '1';
    --                 swir_bit_counter <= 0;
    --             else
    --                 swir_fragment(swir_bit_counter + SWIR_PIXEL_BITS - 1 downto swir_bit_counter) <= std_logic_vector(swir_pixel);
    --                 swir_bit_counter <= swir_bit_counter + SWIR_PIXEL_BITS;
    --             end if;
    --         end if;
        
    --         --The second stage of the swir pipeline, putting the fragment into the fifo chain
    --         if (swir_fragment_ready = '1') then
    --             swir_link_wrreq(swir_store_counter) <= '1';
    --             swir_link_in(swir_store_counter) <= swir_fragment;
    --             swir_fragment_ready <= '0';
    --         else
    --             swir_link_wrreq <= (others => '0');
    --             swir_link_in <= (others => (others => '0'));
    --         end if;
        
    --         --Checking to see if a fifo is full and incrementing the store counter
    --         if (swir_fifo_full(swir_store_counter) = '1') then
    --             swir_store_counter <= swir_store_counter + 1;
    --             num_store_swir_rows <= num_store_swir_rows + 1;
    --         end if;
            
    --         --The final stage
    --         vnir_output_index := vnir_store_counter - num_store_vnir_rows;
    --         swir_output_index := swir_store_counter - num_store_swir_rows;
        
    --         if (row_request = '1') then
    --             transmitting_i <= '1';
    --         end if;
        
    --         if (transmitting_i = '1') then
    --             --These first two branches set the output to the correct fifo
    --             if (num_store_vnir_rows >= num_store_swir_rows and num_store_vnir_rows /= 0 and vnir_fifo_empty(vnir_output_index) = '0') then
    --                 vnir_link_rdreq(vnir_output_index) <= '1';
    --                 fragment_out <= vnir_link_out(vnir_output_index);
    --                 fragment_type <= sdram.sdram_type(row_type_buffer(vnir_output_index));
        
    --             elsif (num_store_swir_rows > num_store_vnir_rows and swir_fifo_empty(swir_output_index) = '0') then
    --                 swir_link_rdreq(swir_output_index) <= '1';
    --                 fragment_out <= swir_link_out(swir_output_index);
    --                 fragment_type <= sdram.ROW_SWIR;
        
    --             --These next two branches reset the output and increment the correct buffer
    --             elsif (vnir_fifo_empty(vnir_output_index) = '1') then
    --                 vnir_link_rdreq(vnir_output_index) <= '0';
    --                 num_store_vnir_rows <= num_store_vnir_rows - 1;
    --                 transmitting_i <= '0';
        
    --             elsif (swir_fifo_empty(swir_output_index) = '1') then
    --                 swir_link_rdreq(swir_output_index) <= '0';
    --                 num_store_swir_rows <= num_store_swir_rows - 1;
    --                 transmitting_i <= '0';
    --             end if;
    --         else
    --             fragment_out <= (others => '0');
    --             fragment_type <= sdram.ROW_NONE;
    --         end if;
    --     end if;
    -- end process pipeline;

    

    -- fifo_clear <= '1' when reset_n = '0' else '0';
    -- transmitting <= transmitting_i;
end architecture;