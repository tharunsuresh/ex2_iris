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

--TODO: 
-- 1) address doesn't change for different rows. overwrites in sdram? 
        -- possible fix, 1 continuous burst of length FIFO_DEPTH
-- 2) buffer appropriate header for image in fifo row #1 and then the image rows

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.avalonmm;
use work.vnir;
use work.sdram;

use work.img_buffer_pkg.all;
use work.swir_types.all;
use work.fpga.all;

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
        row_type            : in sdram.row_type_t;
        address             : in sdram.address_t;
        buffer_transmitting : in std_logic;
        next_row_req        : out std_logic;

        -- Flags for MPU interaction
        sdram_busy          : out std_logic;

        --Avalon bridge for reading and writing to stuff
        sdram_avalon_out    : out avalonmm.from_master_t;
        sdram_avalon_in     : in avalonmm.to_master_t
    );
end entity command_creator;

architecture rtl of command_creator is
   
    -- master attributes
    constant MAXBURSTCOUNT 		      :   integer   :=  256;     -- at most half of FIFODEPTH
    constant BURSTCOUNTWIDTH 	      :   integer   :=  9;      -- log2(MAXBURSTCOUNT)+1
    constant FIFODEPTH			      :   integer   :=  512;	-- must be at least twice MAXBURSTCOUNT in order to be efficient
    constant FIFODEPTH_LOG2 		  :   integer   :=  9;      -- log2(FIFODEPTH)

    signal reset                    : std_logic;
    signal control_write_length     : std_logic_vector(sdram.ADDRESS_LENGTH-1 downto 0);
    signal control_go               : std_logic;
    signal control_done             : std_logic;
    signal user_write_buffer        : std_logic;
    signal user_buffer_data         : std_logic_vector(FIFO_WORD_LENGTH-1 downto 0);
    signal user_buffer_full         : std_logic;
    signal fifo_used_out            : unsigned(FIFODEPTH_LOG2-1 downto 0);

	type state_type is (s0_reset, s1_empty, s2_buffer, s3_write);
        signal state   : state_type;   -- Register to hold the current state

        -- Attribute "safe" implements a safe state machine. 
        -- It can recover from an illegal state (by returning to the reset state).
        attribute syn_encoding : string;
        attribute syn_encoding of state_type : type is "safe";

begin
    DMA_write_component : entity work.DMA_write 
    generic map (
        DATAWIDTH 				=> FIFO_WORD_LENGTH,
        MAXBURSTCOUNT 			=> MAXBURSTCOUNT,
        BURSTCOUNTWIDTH 		=> BURSTCOUNTWIDTH,
        BYTEENABLEWIDTH 		=> FIFO_WORD_BYTES, 
        ADDRESSWIDTH			=> sdram.ADDRESS_LENGTH,
        FIFODEPTH				=> FIFODEPTH,
        FIFODEPTH_LOG2 			=> FIFODEPTH_LOG2,
        FIFOUSEMEMORY 			=> "ON"
    )
    port map (
        clk 					=> clock,
        reset 					=> reset,
        control_fixed_location 	=> '0',
        control_write_base 		=> std_logic_vector(address),
        control_write_length 	=> control_write_length,
        control_go 				=> control_go,
        control_done			=> control_done,
        user_write_buffer		=> user_write_buffer,
        user_buffer_data		=> user_buffer_data,
        user_buffer_full		=> user_buffer_full,
        master_address 			=> sdram_avalon_out.address,
        master_write 			=> sdram_avalon_out.write_cmd,
        master_byteenable 		=> sdram_avalon_out.byte_enable,
        master_writedata 		=> sdram_avalon_out.write_data,
        master_burstcount 		=> sdram_avalon_out.burst_count,
        master_waitrequest 		=> sdram_avalon_in.wait_request,
        fifo_used_out			=> fifo_used_out
    );

    process (reset_n, clock) is
    begin
        if (reset_n = '0') then
            state <= s0_reset;
        elsif rising_edge(clock) then
			case state is
				when s0_reset =>
					if reset_n = '1' then
						state <= s1_empty;
					else
						state <= s0_reset;
					end if;
				when s1_empty =>  
					if buffer_transmitting = '1' then --if rows are coming in, start buffering them
						state <= s2_buffer;
					else
						state <= s1_empty;
					end if;
				when s2_buffer =>
					if buffer_transmitting = '0' then --when rows stop coming in, go to write state
						state <= s3_write;
					else
						state <= s2_buffer;
                    end if;
                when s3_write => 
                    if fifo_used_out = 0 then  --if empty after writing, go to empty state
                        state <= s1_empty;
                    else
                        state <= s3_write;
                    end if;
			end case;
        end if;
    end process;
    
	process (state, clock) is
	begin
		case state is
			when s0_reset =>
                --outputs 
                next_row_req         <= '0';
                sdram_busy           <= '0';
                
                --signals to master
                control_go           <= '0';
                user_write_buffer    <= '0';
                user_buffer_data     <= (others => '0');

            when s1_empty =>
            
                next_row_req         <= '1';
                sdram_busy           <= '0';

                control_go           <= '0';
                user_write_buffer    <= '0';
                user_buffer_data     <= (others => '0');

            when s2_buffer =>

                next_row_req         <= '1';
                sdram_busy           <= '0';

                control_go           <= '0';
                user_write_buffer    <= '1';
                user_buffer_data     <= row_data;

            when s3_write =>
    
                next_row_req         <= '0';
                sdram_busy           <= '1';

                control_go           <= control_done;
                user_write_buffer    <= '0';
                user_buffer_data     <= (others => '0');

		end case;
	end process;

    reset <= NOT reset_n; --reset for DMA_write
    control_write_length <= std_logic_vector(to_unsigned(FIFO_WORD_BYTES, sdram.ADDRESS_LENGTH));    
                
end architecture;