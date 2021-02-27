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

use work.swir_types.all;


entity swir_controller is
    port (
        clock               : in std_logic;
        reset_n             : in std_logic := '0';

        avs_address         : in  std_logic_vector(7 downto 0);
        avs_read            : in  std_logic := '0';
        avs_readdata        : out std_logic_vector(31 downto 0);
        avs_write           : in  std_logic := '0';
        avs_writedata       : in  std_logic_vector(31 downto 0);
        avs_irq             : out std_logic;

        config              : out swir_config_t;
        start_config        : out std_logic;
        config_done         : in  std_logic;

        do_imaging          : out std_logic;
        imaging_done        : in  std_logic
    );
end entity swir_controller;

architecture rtl of swir_controller is

    pure function read_integer(bits : std_logic_vector) return integer is
    begin
        return to_integer(signed(bits));
    end function read_integer;

    pure function to_l32(b : std_logic) return std_logic_vector is
        variable re : std_logic_vector(31 downto 0);
    begin
        re := (0 => b, others => '0');
        return re;
    end function to_l32;

begin

    process (clock, reset_n)
        variable config_done_reg    : std_logic;
        variable config_done_irq    : std_logic;
        variable imaging_done_reg   : std_logic;
        variable imaging_done_irq   : std_logic;
    begin
        if reset_n = '0' then
            start_config <= '0';
            config <= (frame_clocks => 0, exposure_clocks => 0, length => 0);
            config_done_reg  := '0';
            config_done_irq  := '0';
            imaging_done_reg := '0';
            imaging_done_irq := '0';
        elsif rising_edge(clock) then

            start_config <= '0';
            do_imaging <= '0';

            if avs_write = '1' then
                case avs_address is
                    when x"00" => config.length          <= read_integer(avs_writedata);
                    when x"01" => config.frame_clocks    <= read_integer(avs_writedata);
                    when x"02" => config.exposure_clocks <= read_integer(avs_writedata);
                    when x"03" => start_config           <= '1';
                    when x"04" => do_imaging             <= '1';
                    when others =>
                end case;
            elsif avs_read = '1' then
                case avs_address is
                    when x"05" => avs_readdata <= to_l32(config_done_reg);  config_done_irq  := '0';
                    when x"06" => avs_readdata <= to_l32(imaging_done_reg); imaging_done_irq := '0';
                    when others =>
                end case;
            end if;

            if config_done = '1' then
                config_done_reg := '1';
                config_done_irq := '1';
            end if;

            if imaging_done = '1' then
                imaging_done_reg := '1';
                imaging_done_irq := '1';
            end if;

        end if;

        avs_irq <= config_done_irq or imaging_done_irq;
    
    end process;

end architecture rtl;