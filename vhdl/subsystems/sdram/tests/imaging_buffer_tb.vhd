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
use work.sdram;
use work.img_buffer_pkg.all;
use work.fpga_types.all;

entity imaging_buffer_tb is
end entity;

architecture sim of imaging_buffer_tb is
    --Clock frequency is 20 MHz
    constant clock_frequency    : integer := 20000000;
    constant clock_period       : time := 1000 ms / clock_frequency;
    
    --Control inputs
    signal clock                : std_logic := '1';
    signal reset_n              : std_logic := '0';

    --Non-control inputs
    signal vnir_row             : vnir.row_t := (others => "1111111111");
    signal swir_pixel           : swir_pixel_t := "1010101010101010";

    signal fragment_out         : row_fragment_t;
    signal row_type             : sdram.row_type_t;
    signal row_req              : std_logic := '0';
    signal transmitting_o       : std_logic;

    --Outputs
    signal swir_pxl_rdy         : std_logic := '0';
    signal vnir_row_rdy         : vnir.row_type_t := vnir.ROW_NONE;


begin
    clock <= not clock after clock_period / 2;

    imaging_buffer_component : entity work.imaging_buffer port map (
        clock               => clock,
        reset_n             => reset_n,
        vnir_row            => vnir_row,
        swir_pixel          => swir_pixel,
        fragment_out        => fragment_out,
        fragment_type       => row_type,
        row_request         => row_req,
        transmitting        => transmitting_o,
        swir_pixel_ready    => swir_pxl_rdy,
        vnir_row_ready      => vnir_row_rdy
		  );

    process is
    begin
        for i in 0 to 2047 loop
            vnir_row(i) <= to_unsigned(i, 10);
        end loop;

        wait for clock_period * 4;
        reset_n <= '1';

        wait for clock_period * 4;
        vnir_row_rdy <= vnir.ROW_RED;
        swir_pxl_rdy <= '1';

        wait until rising_edge(clock);
        vnir_row_rdy <= vnir.ROW_NONE;
        swir_pxl_rdy <= '0';

        wait for clock_period * 4;
        swir_pxl_rdy <= '1';
        wait until rising_edge(clock);
        swir_pxl_rdy <= '0';

        wait for clock_period * 4;
        swir_pxl_rdy <= '1';
        wait until rising_edge(clock);
        swir_pxl_rdy <= '0';

        wait for clock_period * 4;
        swir_pxl_rdy <= '1';
        wait until rising_edge(clock);
        swir_pxl_rdy <= '0';

        wait for clock_period * 4;
        swir_pxl_rdy <= '1';
        wait until rising_edge(clock);
        swir_pxl_rdy <= '0';

        wait for clock_period * 4;
        swir_pxl_rdy <= '1';
        wait until rising_edge(clock);
        swir_pxl_rdy <= '0';

        wait for clock_period * 4;
        swir_pxl_rdy <= '1';
        wait until rising_edge(clock);
        swir_pxl_rdy <= '0';
        
        wait for clock_period * 170;

        row_req <= '1';
        wait until rising_edge(clock);
        row_req <= '0';
        
        wait;



    end process;
end architecture;
