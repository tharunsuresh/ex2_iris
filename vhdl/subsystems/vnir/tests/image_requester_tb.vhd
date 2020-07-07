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

use work.spi_types.all;
use work.vnir_types.all;

entity image_requester_tb is
end entity;


architecture tests of image_requester_tb is	    
    signal clock            : std_logic := '0';  -- Main clock
    signal reset_n          : std_logic := '1';  -- Main reset
    signal config           : vnir_config_t;
    signal start_config     : std_logic := '0';
    signal num_frames       : integer;
    signal do_imaging       : std_logic := '0';
    signal imaging_done     : std_logic;
    signal sensor_clock     : std_logic := '0';
    signal sensor_reset     : std_logic := '0';
    signal frame_request    : std_logic;
    
    component image_requester is
    generic (
        clocks_per_sec  : integer
    );
    port (
        clock           : in std_logic;
        reset_n         : in std_logic;
        config          : in vnir_config_t;
        start_config    : in std_logic;
        num_frames      : out integer;
        do_imaging      : in std_logic;
        imaging_done    : out std_logic;
        sensor_clock    : in std_logic;
        frame_request   : out std_logic
    ); 
	end component;

begin

    debug : process (do_imaging, frame_request)
    begin
        if rising_edge(do_imaging) then
            report "Detected do_imaging rising edge";
        end if;
        if rising_edge(frame_request) then
            report "Detected frame_request rising edge";
        end if;
    end process debug;

    clock_gen : process
        constant period : time := 20 ns;
	begin
		wait for period / 2;
		clock <= not clock;
    end process clock_gen;
    
    sensor_clock_gen : process
        constant period : time := 0.02083 us;
    begin
        wait for period / 2;
        sensor_clock <= not sensor_clock;
    end process sensor_clock_gen;
    
	test : process
    begin
        
        reset_n <= '0'; wait until rising_edge(clock); reset_n <= '1';
        
        config.imaging_duration <= 1000;
        config.fps <= 30;
        start_config <= '1'; wait until rising_edge(clock); start_config <= '0';

        do_imaging <= '1'; wait until rising_edge(clock); do_imaging <= '0';
        
        wait;

	end process test;

    image_requester_component : image_requester generic map (
        clocks_per_sec => 50000000
    ) port map(
        clock => clock,
        reset_n => reset_n,
        config => config,
        start_config => start_config,
        num_frames => num_frames,
        do_imaging => do_imaging,
        imaging_done => imaging_done,
        sensor_clock => sensor_clock,
        frame_request => frame_request
    );

end tests;