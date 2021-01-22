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
use work.avalonmm;
use work.img_buffer_pkg.all;
use work.swir_types.all;
use work.sdram;
use work.fpga_types.all;

use work.vnir;
use work.vnir."/=";

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
    signal vnir_row_fragments   : vnir_row_fragment_a;

    --Signals for the first stage of the swir pipeline
    signal swir_bit_counter     : integer;
    signal swir_fragment        : row_fragment_t;

    --signals for the second stage of the vnir pipeline
    signal row_type_buffer      : row_type_buffer_a;
    signal vnir_frag_counter    : integer;
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


    
   
    swir: process (clock) is
    begin
        if (rising_edge(clock) and (reset_n /= '0')) then
            --The first stage of the swir_pipeline, accumulating pixels to fill a word
            if (swir_pixel_ready = '1') then

                if (swir_bit_counter = FIFO_WORD_LENGTH) then
                    swir_fragment_ready <= '1';
                    swir_bit_counter <= 0;
                else
                    swir_fragment(swir_bit_counter + SWIR_PIXEL_BITS - 1 downto swir_bit_counter) <= std_logic_vector(swir_pixel);
                    swir_bit_counter <= swir_bit_counter + SWIR_PIXEL_BITS;
                end if;
            end if;
   
            --The second stage of the swir pipeline, putting the fragment into the fifo chain
            if (swir_fragment_ready = '1') then
                swir_link_wrreq(swir_store_counter) <= '1';
                swir_link_in(swir_store_counter) <= swir_fragment;
                swir_fragment_ready <= '0';
            else
                swir_link_wrreq <= (others => '0');
                swir_link_in <= (others => (others => '0'));
            end if;
  
            --Checking to see if a fifo is full and incrementing the store counter
            if (swir_fifo_full(swir_store_counter) = '1') then
                swir_store_counter <= swir_store_counter + 1;
                num_store_swir_rows <= num_store_swir_rows + 1;
            end if;
        end if;
    end process swir;

    

    fifo_clear <= '1' when reset_n = '0' else '0';
    transmitting <= transmitting_i;
end architecture;