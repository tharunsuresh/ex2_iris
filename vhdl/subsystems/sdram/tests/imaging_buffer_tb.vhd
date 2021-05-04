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
use work.fpga.all;

entity imaging_buffer_tb is
end entity;

architecture sim of imaging_buffer_tb is

    constant clock_frequency    : integer := 20000000;  -- 20 MHz
    constant clock_period       : time := 1000 ms / clock_frequency;

    constant reset_period       : time := clock_period * 4;
    
    constant vnir_row_clocks    : time := clock_period * 128; -- clock cycles between VNIR rows
    constant vnir_frame_clocks  : time := clock_period * 3000;

    constant swir_pxl_clocks    : time := clock_period * 64; -- clock cycles between SWIR pixels (1 clock cycle in 0.78125MHz clock, 50/0.78125 = 64)
    constant swir_row_clocks    : time := swir_pxl_clocks * 25; -- clock cycles between SWIR rows
    
    -- Control inputs
    signal clock                : std_logic := '1';
    signal reset_n              : std_logic := '0';

    -- Data inputs
    signal vnir_row             : vnir.row_t := (others => "1111111111");
    signal vnir_row_rdy         : vnir.row_type_t := vnir.ROW_NONE;
    signal swir_pixel           : swir_pixel_t := "1010101010101010";
    signal swir_pxl_rdy         : std_logic := '0';

    -- Imaging Buffer <=> Command Creator 
    signal row_req              : std_logic := '0'; -- input row request
    signal transmitting_o       : std_logic;        -- output flag
    signal fragment_out         : row_fragment_t;   -- output row fragment
    signal row_type             : sdram.row_type_t; -- output row type


begin

    imaging_buffer : entity work.imaging_buffer port map (
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

    clock <= not clock after clock_period / 2;

    reset_process: process
    begin
        reset_n <= '0';
        wait for reset_period; 
        reset_n <= '1';
        wait;
    end process reset_process;

    -- VNIR functionality 
    -- during normal operation, the VNIR subsystem will emit three rows (red, blue and NIR) in a burst 
    -- when it finishes exposing a frame. The pixel integrator operates on one 16-pixel fragment per 
    -- clock cycle, so these rows will be separated by 2048/16=128 clock cycles during the burst. 
    -- The time between bursts depends on the desired frame-rate. It should be about equal to 
    -- (frame_clocks - 3*128), though there may be some inconsistencies here due to clock domain crossing.

    -- The behaviour described above is also the worst case. In some cases (at the beginning and end of an image) 
    -- the burst will consist of only 1 or 2 rows. They should still be separated by 128 clock cycles.

    vnir_process: process
    begin
        for i in 0 to 2047 loop
            vnir_row(i) <= to_unsigned(i, 10);
        end loop;
        wait for reset_period; 

        for i in 1 to 100 loop
            vnir_row_rdy <= vnir.ROW_RED;
            wait until rising_edge(clock);
            vnir_row_rdy <= vnir.ROW_NONE;
            wait for vnir_row_clocks;

            vnir_row_rdy <= vnir.ROW_BLUE;
            wait until rising_edge(clock);
            vnir_row_rdy <= vnir.ROW_NONE;
            wait for vnir_row_clocks;

            vnir_row_rdy <= vnir.ROW_NIR;
            wait until rising_edge(clock);
            vnir_row_rdy <= vnir.ROW_NONE;
            wait for (vnir_frame_clocks-3*vnir_row_clocks);
        end loop;
        wait;
    end process vnir_process;

    -- Duration of each swir pixel: worst case: ~1000 ns; normal: ~1300 ns
    -- A row is 512 pixels, so takes 512 swir clock cycles to arrive, 
    -- where the swir clock is 0.78125 MHz. The time between rows is ~30 clock cycles
    -- swir_pxl_ready is sent on the 50MHz clock, same as the pixel.
    
    swir_process: process is
    begin
        wait for reset_period; 
        for i in 1 to 10 loop 
            for i in 1 to 512 loop -- one row of 512 pixels
                wait until rising_edge(clock);
                swir_pxl_rdy <= '1';
                swir_pixel <= to_unsigned(i, swir_pixel'length);

                wait until rising_edge(clock);
                swir_pxl_rdy <= '0';   
                swir_pixel <= (others => '0');
                
                wait for swir_pxl_clocks;
            end loop;
            wait for swir_row_clocks; -- time between rows
        end loop;
        wait;
    end process swir_process;

    transmit_process: process is 
    begin
        for i in 1 to 1000 loop
            wait for clock_period * 170;
            row_req <= '1';
            wait until rising_edge(clock);
            row_req <= '0';
        end loop;
        wait;
    end process transmit_process; 

end architecture;
