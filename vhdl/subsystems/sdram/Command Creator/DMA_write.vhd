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

-- Based off of the Altera burst write verilog module.
-- Available at: 
-- https://www.intel.com/content/www/us/en/programmable/support/support-resources/design-examples/intellectual-property/embedded/nios-ii/exm-avalon-mm.html

-- This circuit simplifies the DMA by taking care of the interface with Avalon MM signals, while providing a FIFO buffer using Altera SCFIFO IP.
-- SIGNALS:
--		clk (i/p):						Input clock.
--		reset (i/p):					Resets signals to default states.
--
-- 		control_fixed_location (i/p):	When set, the master address will not increment
--		control_write_base (i/p): 		Word aligned byte address where the master will begin transferring data
-- 		control_write_length (i/p): 	Number of bytes to transfer. This number must be a multiple of the
--											data width in bytes (e.g. 32 bit data requires a multiple of 4)
--		control_go (i/p): 				One clock cycle strobe that instructs the master to begin transferring.
--											The fixed_location, base, and length values are registered on this clock cycle
--		control_done (o/p): 			Asserted and held when the master has transferred the last word of data.
--											This occurs when the last write transfer completes or the last pending read returns.
--											You can start the master again on the next cycle after done is asserted.
--
--		user_buffer_data (i/p):			Valid data word that your logic writes into the user buffer. Use "user_write_buffer" to
--											qualify it as valid data when 'user_buffer_full' is de-asserted.
--		user_buffer_full (o/p):			When asserted the user buffer is full and you must not write any more data.
--											Asserting 'user_write_buffer' while this signal is asserted may lead data
--											being lost and the write master failing to complete the entire transfer.
--		user_write_buffer (i/p):		Acts as a write qualifier. Assert this signal to write valid data into the user buffer.
--											You must not assert this signal if 'user_buffer_full' is asserted otherwise data
--											overflow will occur.
--
-- GENERICS:
--		DATAWIDTH (8, 16, 32, 64, 128, 512, 1024):
--										Data path width
--		MAXBURSTCOUNT (1, 2, 4, 8, 16, 32, 64, 128):
--										Maximum number of beats in a burst. Must be at most half of FIFODEPTH for the master to
--											access memory locations efficiently.
--		BURSTCOUNTWIDTH (1-8):			Log2(MAXBURSTCOUNT) + 1
--		BYTEENABLEWIDTH (1, 2, 4, 8, 16, 32, 64, 128)):
--										(DATAWIDTH)/8
--		ADDRESSWIDTH (1-32):			The number of address bits exposed to the system interconnect fabric. This number must be
--											large enough to span all the components connected to the master.
--		FIFODEPTH (4, 8, 16, 32, 64, 128):
--										FIFO depth of the internal buffer. You should set this to be at least twice the MAXBURSTCOUNT
--											value so that the master operates at peak efficiency.
--		FIFODEPTH_LOG2 (2-7):			Log2(FIFODEPTH)
--		FIFOUSEMEMORY ("ON"/"OFF"):		Set to "ON" to use on-chip memory for the internal buffer. Set to "OFF" to use logic elements
--											instead of memory (not recommended if FIFODEPTH is larger than 4).

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library altera_mf;
	use altera_mf.all;

entity DMA_write is
	generic (
		DATAWIDTH 				: natural := 128;
		MAXBURSTCOUNT 			: natural := 128;
		BURSTCOUNTWIDTH 		: natural := 8;
		BYTEENABLEWIDTH 		: natural := 16;
		ADDRESSWIDTH			: natural := 28;
		FIFODEPTH				: natural := 128;	-- must be at least twice MAXBURSTCOUNT in order to be efficient
		FIFODEPTH_LOG2 			: natural := 7;
		FIFOUSEMEMORY 			: string := "ON"	-- set to "OFF" to use LEs instead
	);
	port (
		clk 					: in std_logic;
		reset 					: in std_logic;
		
		-- control inputs and outputs
		control_fixed_location 	: in std_logic; -- this only makes sense to enable when MAXBURSTCOUNT = 1
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
		master_waitrequest 		: in std_logic;

		--fifo used
		fifo_used_out			: out unsigned(FIFODEPTH_LOG2-1 downto 0)
	);
end DMA_write;

architecture main of DMA_write is

	signal control_fixed_location_d1	: std_logic;
	signal length_v						: unsigned(ADDRESSWIDTH-1 downto 0);
	signal final_short_burst_enable		: std_logic;  										-- when the length is less than MAXBURSTCOUNT * # of bytes per word (BYTEENABLEWIDTH) (i.e. end of the transfer)
	signal final_short_burst_ready		: std_logic;										-- when there is enough data in the FIFO for the final burst
	signal burst_boundary_word_address	: unsigned(BURSTCOUNTWIDTH-1 downto 0);				-- represents the word offset within the burst boundary
	signal first_short_burst_count		: unsigned(BURSTCOUNTWIDTH-1 downto 0);
	signal final_short_burst_count		: unsigned(BURSTCOUNTWIDTH-1 downto 0);
	signal first_short_burst_enable		: std_logic;										-- when the transfer doesn't start on a burst boundary
	signal first_short_burst_ready		: std_logic;										-- when there is enough data in the FIFO to get the master back into burst alignment
	signal full_burst_ready				: std_logic;										-- when there is enough data in the FIFO for a full burst
	signal increment_address			: std_logic;										-- this increments the 'address' register when write is asserted and waitrequest is de-asserted
	signal burst_begin					: std_logic;										-- used to register the registers 'burst_address' and 'burst_count_d1' as well as drive the master_address and burst_count muxes
	signal read_fifo					: std_logic := '0';
	signal fifo_used					: unsigned(FIFODEPTH_LOG2-1 downto 0);				-- going to combined used with the full bit
	signal burst_count					: unsigned(BURSTCOUNTWIDTH-1 downto 0);				-- watermark of the FIFO, it has a latency of 2 cycles
	signal burst_counter				: unsigned(BURSTCOUNTWIDTH-1 downto 0);
	signal first_transfer				: std_logic;										-- need to keep track of the first burst so that we don't incorrectly increment the address
	
	-- Signals added to facilitate writing certain bits of signals
	signal burst_boundary_word_address_fullLength	: unsigned(ADDRESSWIDTH-1 downto 0);
	signal final_short_burst_count_fullLength		: unsigned(ADDRESSWIDTH-1 downto 0);
	-- Signals added to facilitate signal conversion
	signal fifo_used_logic							: std_logic_vector(FIFODEPTH_LOG2-1 downto 0);
	-- Signals added to allow "reading" of port output signals, which is not allowed until VHDL 2008
	signal master_address_reg						: unsigned(ADDRESSWIDTH-1 downto 0);
	signal master_burstcount_reg					: unsigned(BURSTCOUNTWIDTH-1 downto 0);
	signal master_write_reg							: std_logic;
	signal control_done_reg							: std_logic;
	
	component scfifo
	generic (
		add_ram_output_register			: string	:= "OFF";
		allow_rwcycle_when_full			: string	:= "OFF";
		almost_empty_value				: natural	:= 0;
		almost_full_value				: natural	:= 0;
		intended_device_family			: string	:= "unused";
		enable_ecc						: string	:= "FALSE";
		lpm_numwords					: natural;
		lpm_showahead					: string	:= "OFF";
		lpm_width						: natural;
		lpm_widthu						: natural	:= 1;
		overflow_checking				: string	:= "ON";
		ram_block_type					: string	:= "AUTO";
		underflow_checking				: string	:= "ON";
		use_eab							: string	:= "ON";
		lpm_hint						: string	:= "UNUSED";
		lpm_type						: string	:= "scfifo"
	);
	port(
		aclr							: in std_logic := '0';
		almost_empty					: out std_logic;
		almost_full						: out std_logic;
		clock							: in std_logic;
		data							: in std_logic_vector(lpm_width-1 downto 0);
		eccstatus						: out std_logic_vector(1 downto 0);
		empty							: out std_logic;
		full							: out std_logic;
		q								: out std_logic_vector(lpm_width-1 downto 0);
		rdreq							: in std_logic;
		sclr							: in std_logic := '0';
		usedw							: out std_logic_vector(lpm_widthu-1 downto 0);
		wrreq							: in std_logic
	);
	end component;
	
begin
	SDRAM_fifo: component scfifo
	generic map(
		add_ram_output_register			=> "OFF",
		intended_device_family 			=> "Cyclone V",
		almost_full_value				=> (FIFODEPTH - 2),
		lpm_numwords					=> FIFODEPTH,
		lpm_showahead					=> "ON",
		lpm_width						=> DATAWIDTH,
		lpm_widthu						=> FIFODEPTH_LOG2,
		overflow_checking				=> "OFF",
		underflow_checking				=> "OFF",
		use_eab							=> FIFOUSEMEMORY
	)
	port map(
		aclr							=> reset,
		almost_empty					=> open,
		almost_full						=> user_buffer_full,
		clock							=> clk,
		data							=> user_buffer_data,
		eccstatus						=> open,
		empty							=> open,
		full							=> open,
		q								=> master_writedata,
		rdreq							=> read_fifo,
		sclr							=> '0', -- default value
		usedw							=> fifo_used_logic,
		wrreq							=> user_write_buffer
	);

	process(clk)
	begin
	
		-- registering the control_fixed_location bit
		if (reset = '1') then
			control_fixed_location_d1 <= '0';
			
		elsif (rising_edge(clk)) then
		
			if (control_go = '1') then
				control_fixed_location_d1 <= control_fixed_location;
			end if;
			
		end if;
		
	end process;


	-- set when control_go fires, and reset once the first burst starts
	process(clk)
	begin
	
		if (reset = '1') then
			first_transfer <= '0';
			
		elsif (rising_edge(clk)) then
		
			if (control_go = '1') then
				first_transfer <= '1';
			elsif (burst_begin = '1') then
				first_transfer <= '0';
			end if;
		end if;
		
	end process;
	
	-- master address (held constant during burst)
	process(clk)
	begin
	
		if (reset = '1') then
			master_address_reg <= (others => '0');
			
		elsif (rising_edge(clk)) then
		
			if (control_go = '1') then
				master_address_reg <= unsigned(control_write_base);
			elsif ((first_transfer = '0') and (burst_begin = '1') and (control_fixed_location_d1 = '0')) then
				  -- we don't want address + BYTEENABLEWIDTH for the first access
				master_address_reg <= master_address_reg + (master_burstcount_reg *  to_unsigned(BYTEENABLEWIDTH,8));

			end if;
		
		end if;
		
	end process;
	
	
	-- master length logic
	process(clk)
	begin
	
		if (reset = '1') then
			length_v <= (others=>'0');
			
		elsif (rising_edge(clk)) then
		
			if (control_go = '1') then
				length_v <= unsigned(control_write_length);
			elsif (increment_address = '1') then
				length_v <= length_v - BYTEENABLEWIDTH;
			end if;
			
		end if;
		
	end process;
	
	
	-- register the master burstcount (held constant during burst)
	process(clk)
	begin
	
		if (reset = '1') then
			master_burstcount_reg <= (others => '0');
			
		elsif (rising_edge(clk)) then
			if (burst_begin = '1') then
				master_burstcount_reg <= burst_count;
			end if;
			
		end if;
		
	end process;
	
	
	-- burst counter.  This is set to the burst count being posted then counts down when each word
	-- of data goes out.  If it reaches 0 (i.e. not reloaded after 1) then the master stalls due to
	-- a lack of data to post a new burst.
	process(clk)
	begin
	
		if (reset = '1') then
			burst_counter <= (others=>'0');
			
		elsif (rising_edge(clk)) then
		
			if (control_go = '1') then
				burst_counter <= (others=>'0');
			elsif (burst_begin = '1') then
				burst_counter <= burst_count;
			elsif (increment_address = '1') then
				burst_counter <= burst_counter - 1;
			end if;
			
		end if;
		
	end process;

	-- Signals added to allow "reading" of port output signals, which is not allowed until VHDL 2008
	fifo_used <= unsigned(fifo_used_logic);
	master_address <= std_logic_vector(master_address_reg);
	master_burstcount <= std_logic_vector(master_burstcount_reg);
	control_done <= control_done_reg;
	master_write <= master_write_reg;

	-- burst boundaries are on the master "width * maximum burst count".  The burst boundary word address will be used to determine how far off the boundary the transfer starts from.
	burst_boundary_word_address_fullLength <= (master_address_reg / BYTEENABLEWIDTH) and (to_unsigned(MAXBURSTCOUNT - 1, master_address_reg'length));
	burst_boundary_word_address <= burst_boundary_word_address_fullLength(BURSTCOUNTWIDTH-1 downto 0);
	
	-- first short burst enable will only be active on the first transfer (if applicable).  It will either post the amount of words remaining to reach the end of the burst
	-- boundary or post the remainder of the transfer whichever is shorter.  If the transfer is very short and not aligned on a burst boundary then the same logic as the final short transfer is used
	first_short_burst_enable <= '1' when (burst_boundary_word_address /= 0) and (first_transfer = '1') else '0';
	
	-- if the burst boundary isn't a multiple of 2 then must post a burst of 1 to get to a multiple of 2 for the next burst
	first_short_burst_count <= to_unsigned(1, first_short_burst_count'length) when burst_boundary_word_address(0) = '1' else
								(MAXBURSTCOUNT - burst_boundary_word_address) when (MAXBURSTCOUNT - burst_boundary_word_address) < (length_v/BYTEENABLEWIDTH) else
								final_short_burst_count;
	first_short_burst_ready <= '1' when (fifo_used > first_short_burst_count) or ((fifo_used = first_short_burst_count) and (burst_counter = 0)) else '0';
	
	-- when there isn't enough data for a full burst at the end of the transfer a short burst is sent out instead
	final_short_burst_enable <= '1' when length_v < (MAXBURSTCOUNT*BYTEENABLEWIDTH) else '0';
	final_short_burst_count_fullLength <= (length_v/BYTEENABLEWIDTH);
	final_short_burst_count <= final_short_burst_count_fullLength(BURSTCOUNTWIDTH-1 downto 0);

	-- this will add a one cycle stall between bursts, since fifo_used has a cycle of latency, this only affects the last burst
	final_short_burst_ready <= '1' when (fifo_used > final_short_burst_count) or ((fifo_used = final_short_burst_count) and (burst_counter = 0)) else '0';
	
	-- since the fifo has a latency of 1 we need to make sure we don't under flow
	-- when fifo used watermark equals the burst count the statemachine must stall for one cycle, this will make sure that when a burst begins there really is enough data present in the FIFO
	full_burst_ready <= '1' when (fifo_used > MAXBURSTCOUNT) or ((fifo_used = MAXBURSTCOUNT) and (burst_counter = 0)) else '0';
	
	-- all ones, always performing word size accesses
	master_byteenable <= (others=>'1');
	control_done_reg <= '1' when (length_v = 0) else '0';

	-- burst_counter = 0 means the transfer is done, or not enough data in the fifo for a new burst
	master_write_reg <= '1' when (control_done_reg = '0') and (burst_counter /= 0) else '0';
	
	burst_begin <= '1' when (((first_short_burst_enable = '1') and (first_short_burst_ready = '1'))
						or ((final_short_burst_enable = '1') and (final_short_burst_ready = '1'))
						or (full_burst_ready = '1'))
						and (control_done_reg = '0') -- since the FIFO can have data before the master starts we need to disable this bit from firing when length = 0
						and ((burst_counter = 0) or ((burst_counter = 1) and (master_waitrequest = '0') and (length_v > (MAXBURSTCOUNT * BYTEENABLEWIDTH)))) -- need to make a short final burst doesn't start right after a full burst completes.
						else '0';
	
	-- alignment correction gets priority, if the transfer is short and unaligned this will cover both
	burst_count <= first_short_burst_count when first_short_burst_enable = '1' else
					final_short_burst_count when final_short_burst_enable = '1' else
					to_unsigned(MAXBURSTCOUNT, burst_count'length);
					
	-- writing is occuring without wait states
	increment_address <= '1' when (master_write_reg = '1') and (master_waitrequest = '0') else '0';
	read_fifo <= increment_address;

	-- output fifo_used for command creator
	fifo_used_out <= fifo_used;
	
end main;