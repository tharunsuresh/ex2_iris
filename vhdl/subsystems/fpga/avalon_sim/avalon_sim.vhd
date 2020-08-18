-- avalon_sim.vhd
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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- use work.avalonmm_types.all;
-- use work.sdram_types.all;
-- use work.vnir_types.all;
-- use work.swir_types.all;
-- use work.fpga_types.all;

entity avalon_sim is
	port (
		reset_n                : in  std_logic                     := '1';
		clock                  : in  std_logic                     := '0'                                       
	);
end entity avalon_sim;

architecture rtl of avalon_sim is

component qsys_interface is
	port (
		avalon_slave_write_n   : in  std_logic                     := '0';             -- avalon_slave.write_n
		avalon_slave_writedata : in  std_logic_vector(31 downto 0) := (others => '0'); --             .writedata
		conduit_end_avalon     : out std_logic_vector(31 downto 0);                    --  conduit_end.new_signal
		reset_n                : in  std_logic                     := '0';             --        reset.reset_n
		clock                  : in  std_logic                     := '0'              --        clock.clk
	);
end component qsys_interface;

------ these go to lower level subsystems -------
type flip is
	(FLIP_NONE, FLIP_X, FLIP_Y, FLIP_XY);

signal vnir_config_window_blue_lo: 			integer:= 0;
signal vnir_config_window_blue_hi: 			integer:= 0;
signal vnir_config_window_red_lo: 			integer:= 0;
signal vnir_config_window_red_hi: 			integer:= 0;
signal vnir_config_window_nir_lo: 			integer:= 0;
signal vnir_config_window_nir_hi: 			integer:= 0;

signal vnir_config_calibration_vramp1: 	integer:= 0;
signal vnir_config_calibration_vramp2: 	integer:= 0;
signal vnir_config_calibration_adc_gain: 	integer:= 0;
signal vnir_config_calibration_offset: 	integer:= 0;
signal vnir_start_config: 						std_logic:= '0';

signal vnir_config_flip: flip;

signal sdram_config_out_memory_base: 		std_logic_vector(31 downto 0);
signal sdram_config_out_memory_bounds: 	std_logic_vector(31 downto 0);
signal sdram_start_config: 					std_logic:= '0';

signal vnir_image_config_duration: 			integer:= 0;
signal vnir_image_config_exposure_time: 	integer:= 0;
signal vnir_image_config_fps: 				integer:= 0;
signal vnir_start_image_config: 				std_logic:= '0';

signal vnir_do_imaging: 						std_logic:= '0';

signal config_confirmed: 						std_logic:= '0';

signal image_config_confirmed: 				std_logic:= '0';

signal unexpected_identifier: 				std_logic:= '0';

signal data_conduit:                      std_logic_vector(31 downto 0);

signal conduit_end_avalon: 					std_logic_vector(31 downto 0);
-----------------------------------------------

begin 

qsys_interface_portmapping: qsys_interface 
	port map (
	conduit_end_avalon => conduit_end_avalon,
	--avalon_slave_writedata => avalon_slave_writedata,
	--avalon_slave_write_n => avalon_slave_write_n,
	reset_n => reset_n,
	clock => clock
	);

	--------------------------------------------------------------------
	-- process for assigning data to subsystems based on identifier bits
	-- this program knows which bits to expect over the Avalon MM interface based on
	-- 8 identifier bits which comprise bits [7..0] of every transfer.
	--------------------------------------------------------------------

	get_data_from_avalon: process (clock)
	
	begin
		
		data_conduit <= conduit_end_avalon;
	
		if (reset_n = '0') then -- do something, maybe? Or not.	
		else
			
		case data_conduit(7 downto 0) is 
				
		-- VNIR subsystem configuration
		when "00000001" =>
			vnir_config_window_blue_lo <= to_integer(unsigned(data_conduit(18 downto 8)));
			vnir_config_window_blue_hi <= to_integer(unsigned(data_conduit(29 downto 9)));
			
		when "00000010" => 
			vnir_config_window_red_lo <= to_integer(unsigned(data_conduit(18 downto 8)));
			vnir_config_window_red_hi <= to_integer(unsigned(data_conduit(29 downto 9)));
			
		when "00000011" => 
			vnir_config_window_nir_lo <= to_integer(unsigned(data_conduit(18 downto 8)));
			vnir_config_window_nir_hi <= to_integer(unsigned(data_conduit(29 downto 9)));				
			
		when "00000100" =>
			vnir_config_calibration_vramp1 <= to_integer(unsigned(data_conduit(14 downto 8)));
			vnir_config_calibration_vramp2 <= to_integer(unsigned(data_conduit(21 downto 15)));
			vnir_config_calibration_adc_gain <= to_integer(unsigned(data_conduit(29 downto 22)));				
			if (data_conduit(31 downto 30) = "00") then
				vnir_config_flip <= FLIP_NONE;
			elsif (data_conduit(31 downto 30) = "01") then
				vnir_config_flip <= FLIP_X;
			elsif (data_conduit(31 downto 30) = "10") then
				vnir_config_flip <= FLIP_Y;
			else
				vnir_config_flip <= FLIP_XY;
			end if;
			
		when "00000101" =>
			vnir_config_calibration_offset <= to_integer(unsigned(data_conduit(21 downto 8)));
			vnir_start_config <= data_conduit(22); -- will be a '1' to start config
				
		-- SDRAM subsystem configuration 
		-- Note that Avalon MM 32-bit wide interface not large enough with identifier bits, so
		-- we need to split up the memory base and bounds into multiple transfers
		when "00000110" =>
			sdram_config_out_memory_base(23 downto 0) <= data_conduit(31 downto 8);
		
		when "00000111" =>
			sdram_config_out_memory_base(27 downto 24) <= data_conduit(11 downto 8);
			sdram_config_out_memory_bounds(19 downto 0) <= data_conduit(31 downto 12);
			
		when "00001000" =>
			sdram_config_out_memory_bounds(27 downto 20) <= data_conduit(15 downto 8);
			sdram_start_config <= data_conduit(16); -- will be a '1' to start config
			
		-- SWIR subsystem configuration 
		-- TO DO: add all SWIR
	
		-- image config

		when "00001001" =>
			vnir_image_config_duration <= to_integer(unsigned(data_conduit(23 downto 8)));
			vnir_image_config_exposure_time <= to_integer(unsigned(data_conduit(31 downto 24)));
						
		when "00001010" =>	
			vnir_image_config_fps <= to_integer(unsigned(data_conduit(17 downto 8)));
			vnir_start_image_config <= data_conduit(18); -- will be a '1' to start config
			
		-- general signals
			
		when "00010000" =>
			-- init_timestamp (write this code)
			
		when "00010001" =>
			vnir_do_imaging <= data_conduit(8);		
				
		when "00010010" =>
			config_confirmed <= data_conduit(8); 
	
		when "00010011" =>
			image_config_confirmed <= data_conduit(8); 
	
		when others =>
			unexpected_identifier <= '1'; -- and then what
				
		end case;
		end if;
	end process;

end rtl;