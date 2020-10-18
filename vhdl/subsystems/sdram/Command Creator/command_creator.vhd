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

use work.avalonmm;
use work.vnir;
use work.sdram;

use work.img_buffer_pkg.all;
use work.swir_types.all;
use work.fpga_types.all;

entity command_creator is
    port(
        --Control Signals
        clock               : in std_logic;
        reset_n             : in std_logic;

        --Header data
        vnir_img_header     : in sdram.header_t;
        swir_img_header     : in sdram.header_t;

        --Rows
        row_data            : in row_fragment_t;
        address             : in sdram.address_t;
        next_row_req        : out std_logic;
        row_done            : in std_logic;

        -- Flags for MPU interaction
        sdram_busy          : out std_logic;

        --Avalon bridge for reading and writing to stuff
        sdram_avalon_out    : out avalonmm.from_master_t;
        sdram_avalon_in     : in avalonmm.to_master_t
    );
end entity command_creator;

architecture rtl of command_creator is
   
    signal write_length     : std_logic_vector(sdram.ADDRESS_LENGTH-1 downto 0);
    signal input_loaded     : std_logic;
    signal write_done       : std_logic;
    signal write_to_buffer  : std_logic;
    signal buffer_data      : std_logic_vector(FIFO_WORD_LENGTH-1 downto 0);
    signal buffer_full      : std_logic;

begin
    DMA_write_component : entity work.DMA_write 
    generic map (
        DATAWIDTH 				=> FIFO_WORD_LENGTH,
        MAXBURSTCOUNT 			=> 128,
        BURSTCOUNTWIDTH 		=> 8,
        BYTEENABLEWIDTH 		=> 8,
        ADDRESSWIDTH			=> sdram.ADDRESS_LENGTH,
        FIFODEPTH				=> 256,
        FIFODEPTH_LOG2 			=> 8,
        FIFOUSEMEMORY 			=> "ON"
    )
    port map (
        clk 					=> clock,
        reset 					=> reset_n,
        control_fixed_location 	=> '0',
        control_write_base 		=> std_logic_vector(address),
        control_write_length 	=> write_length,
        control_go 				=> input_loaded,
        control_done			=> write_done,
        user_write_buffer		=> write_to_buffer,
        user_buffer_data		=> buffer_data,
        user_buffer_full		=> buffer_full,
        master_address 			=> sdram_avalon_out.address,
        master_write 			=> sdram_avalon_out.write_cmd,
        master_byteenable 		=> sdram_avalon_out.byte_enable,
        master_writedata 		=> sdram_avalon_out.write_data,
        master_burstcount 		=> sdram_avalon_out.burst_count,
        master_waitrequest 		=> sdram_avalon_in.wait_request
    );
end architecture;