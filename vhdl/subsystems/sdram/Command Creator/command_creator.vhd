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
        -- row_done            : in std_logic;

        -- Flags for MPU interaction
        sdram_busy          : out std_logic;

        --Avalon bridge for reading and writing to stuff
        sdram_avalon_out    : out avalonmm.from_master_t;
        sdram_avalon_in     : in avalonmm.to_master_t
    );
end entity command_creator;

architecture rtl of command_creator is
    component DMA_write is
        generic (
            DATAWIDTH 				: natural := 128;
            MAXBURSTCOUNT 			: natural := 128;
            BURSTCOUNTWIDTH 		: natural := 8;
            BYTEENABLEWIDTH 		: natural := 16;
            ADDRESSWIDTH			: natural := 28;
            FIFODEPTH				: natural := 128;
            FIFODEPTH_LOG2 			: natural := 7;
            FIFOUSEMEMORY 			: string := "ON"
	    );
        port (
            clk 					: in std_logic;
            reset 					: in std_logic;
            
            -- control inputs and outputs
            control_fixed_location 	: in std_logic;
            control_write_base 		: in std_logic_vector(ADDRESSWIDTH-1 downto 0);
            control_write_length 	: in std_logic_vector(ADDRESSWIDTH-1 downto 0);
            control_go 				: in std_logic;
            control_done			: out std_logic;
            
            -- user logic inputs and outputs
            user_write_buffer		: in std_logic;
            user_buffer_data		: in std_logic_vector(DATAWIDTH-1 downto 0);
            user_buffer_full		: out std_logic;
            
            -- master inputs and outputs
            master_address 			: out std_logic_vector(ADDRESSWIDTH-1 downto 0);
            master_write 			: out std_logic;
            master_byteenable 		: out std_logic_vector(BYTEENABLEWIDTH-1 downto 0);
            master_writedata 		: out std_logic_vector(DATAWIDTH-1 downto 0);
            master_burstcount 		: out std_logic_vector(BURSTCOUNTWIDTH-1 downto 0);
            master_waitrequest 		: in std_logic
        );
    end component;

    signal write_length     : std_logic_vector(sdram.ADDRESS_LENGTH-1 downto 0);
    signal input_loaded     : std_logic;
    signal write_done       : std_logic;
    signal write_to_buffer  : std_logic;
    signal buffer_data      : std_logic_vector(FIFO_WORD_LENGTH-1 downto 0);
    signal buffer_full      : std_logic;

begin
    DMA_write_component : DMA_write 
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