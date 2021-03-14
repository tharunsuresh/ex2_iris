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
use work.avalonmm;
use work.vnir;
use work.swir_types.all;
use work.sdram.all;
use work.fpga.all;

entity header_creator_tb is
end entity;

architecture sim of header_creator_tb is
    --Clock frequency is 20 MHz
    constant clock_frequency    : integer := 20000000;
    constant clock_period       : time := 1000 ms / clock_frequency;
    
    --Control inputs
    signal clock                : std_logic := '1';
    signal reset_n              : std_logic := '0';

    --Non-control inputs
    signal timestamp            : timestamp_t := to_unsigned(0, timestamp_t'length);
    signal vnir_rows            : integer := 0;
    signal swir_rows            : integer := 0;
    signal sending_img          : std_logic := '0';

    --Outputs
    signal swir_img_header      : std_logic_vector(159 downto 0);
    signal vnir_img_header      : std_logic_vector(159 downto 0);
begin
    i_header_creator : entity work.header_creator(rtl)
    port map(
        clock           => clock,
        reset_n         => reset_n,
        timestamp       => timestamp,
        vnir_rows       => vnir_rows,
        swir_rows       => swir_rows,
        img_config_done => sending_img,
        swir_img_header => swir_img_header,
        vnir_img_header => vnir_img_header);
    
    clock <= not clock after clock_period / 2;

    --Testing stuff
    testing_process : process is
    begin
        --Waiting two clock cycles before taking it out of reset
        wait until rising_edge(clock);
        wait until rising_edge(clock);

        reset_n <= '1';
        
        wait until rising_edge(clock);

        timestamp <= to_unsigned(1594402392, 64);
        vnir_rows <= 23;
        swir_rows <= 12;

        wait until (swir_img_header(102) /= '0');

        sending_img <= '1';

        wait until rising_edge(clock);
        swir_rows <= 0;
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        sending_img <= '0';
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        wait until rising_edge(clock);
        
        wait;

    end process testing_process;
end architecture;