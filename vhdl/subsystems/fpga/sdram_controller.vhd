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

use work.sdram;
use work.fpga.timestamp_t;

entity sdram_controller is
    port (
        clock               : in std_logic;
        reset_n             : in std_logic := '0';

        avs_address         : in  std_logic_vector(7 downto 0);
        avs_read            : in  std_logic := '0';
        avs_readdata        : out std_logic_vector(31 downto 0);
        avs_write           : in  std_logic := '0';
        avs_writedata       : in  std_logic_vector(31 downto 0);
        avs_irq             : out std_logic;

        swir_num_rows       : out integer;
        vnir_num_rows       : out integer;

        timestamp           : out timestamp_t;
        mpu_memory_change   : out sdram.address_block_t;
        config_to_sdram     : out sdram.config_to_sdram_t;
        start_config        : out std_logic;
        config_from_sdram   : in  sdram.memory_state_t;
        config_done         : in  std_logic;
        img_config_done     : in  std_logic;

        sdram_busy          : in std_logic;
        sdram_error         : in sdram.error_t
    );
end entity sdram_controller;

architecture rtl of sdram_controller is
    
    -- TODO: test if resize() works properly with signed values (particularly in <0 case)

    pure function read_address(bits : std_logic_vector) return sdram.address_t is
    begin
        return sdram.address_t(resize(signed(bits), sdram.ADDRESS_LENGTH));
    end function read_address;

    pure function read_integer(bits : std_logic_vector) return integer is
    begin
        return to_integer(signed(bits));
    end function read_integer;

    pure function read_unsigned(bits : std_logic_vector; size : integer) return unsigned is
    begin
        return resize(unsigned(bits), size);
    end function read_unsigned;

    pure function to_l32(addr : sdram.address_t) return std_logic_vector is
    begin
        return std_logic_vector(resize(signed(addr), 32));
    end function to_l32;

    pure function to_l32(b : std_logic) return std_logic_vector is
        variable re : std_logic_vector(31 downto 0);
    begin
        re := (0 => b, others => '0');
        return re;
    end function to_l32;

    pure function to_l32(i : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_signed(i, 32));
    end function to_l32;

    pure function to_l32(e : sdram.error_t) return std_logic_vector is
    begin
        case e is
            when sdram.no_error         => return x"00000000";
            when sdram.full             => return x"00000001";
            when sdram.mpu_check_failed => return x"00000002";
        end case;
    end function to_l32;

begin
    
    process (clock, reset_n)
        variable config_done_reg : std_logic;
        variable config_done_irq : std_logic;

        variable image_config_done_reg : std_logic;
        variable image_config_done_irq : std_logic;

        variable vnir_num_rows_reg : integer;
        variable swir_num_rows_reg : integer;
    begin
        if reset_n = '0' then
            config_to_sdram <= (memory_base => sdram.UNDEFINED_ADDRESS, memory_bounds => sdram.UNDEFINED_ADDRESS);
            swir_num_rows   <= 0;
            vnir_num_rows   <= 0;
            config_done_reg := '0';
            config_done_irq := '0';
            image_config_done_reg := '0';
            image_config_done_irq := '0';
            
            vnir_num_rows_reg := 0;
            swir_num_rows_reg := 0;
            vnir_num_rows <= 0;
            swir_num_rows <= 0;
        elsif rising_edge(clock) then

            start_config <= '0';
            vnir_num_rows <= 0;
            swir_num_rows <= 0;

            if avs_write = '1' then
                case avs_address is
                when x"00" => config_to_sdram.memory_base   <= read_address(avs_writedata);
                when x"01" => config_to_sdram.memory_bounds <= read_address(avs_writedata);
                when x"02" => swir_num_rows_reg             := read_integer(avs_writedata);
                when x"03" => vnir_num_rows_reg             := read_integer(avs_writedata);
                when x"04" => timestamp(31 downto 0)        <= read_unsigned(avs_writedata, 32);
                when x"05" => timestamp(63 downto 32)       <= read_unsigned(avs_writedata, 32);
                when x"06" => mpu_memory_change(0)          <= read_address(avs_writedata);
                when x"07" => mpu_memory_change(1)          <= read_address(avs_writedata);
                
                when x"08" => start_config <= '1';
                              config_done_reg := '0';
                when x"09" => swir_num_rows <= swir_num_rows_reg;
                              vnir_num_rows <= vnir_num_rows_reg;
                              image_config_done_reg := '0';
                when others =>
                end case;
            elsif avs_read = '1' then
                case avs_address is
                when x"0A" => avs_readdata <= to_l32(config_done_reg); config_done_irq := '0';
                when x"0B" => avs_readdata <= to_l32(image_config_done_reg); image_config_done_irq := '0';

                when x"0C" => avs_readdata <= to_l32(config_from_sdram.vnir.base);
                when x"0D" => avs_readdata <= to_l32(config_from_sdram.vnir.bounds);
                when x"0E" => avs_readdata <= to_l32(config_from_sdram.vnir.fill_bounds);
                when x"0F" => avs_readdata <= to_l32(config_from_sdram.vnir.fill_base);
                when x"10" => avs_readdata <= to_l32(config_from_sdram.swir.base);
                when x"11" => avs_readdata <= to_l32(config_from_sdram.swir.bounds);
                when x"12" => avs_readdata <= to_l32(config_from_sdram.swir.fill_bounds);
                when x"13" => avs_readdata <= to_l32(config_from_sdram.swir.fill_base);
                when x"14" => avs_readdata <= to_l32(config_from_sdram.vnir_temp.base);
                when x"15" => avs_readdata <= to_l32(config_from_sdram.vnir_temp.bounds);
                when x"16" => avs_readdata <= to_l32(config_from_sdram.vnir_temp.fill_bounds);
                when x"17" => avs_readdata <= to_l32(config_from_sdram.vnir_temp.fill_base);
                when x"18" => avs_readdata <= to_l32(config_from_sdram.swir_temp.base);
                when x"19" => avs_readdata <= to_l32(config_from_sdram.swir_temp.bounds);
                when x"1A" => avs_readdata <= to_l32(config_from_sdram.swir_temp.fill_bounds);
                when x"1B" => avs_readdata <= to_l32(config_from_sdram.swir_temp.fill_base);
                when x"1C" => avs_readdata <= to_l32(sdram_busy);
                when x"1D" => avs_readdata <= to_l32(sdram_error);
                when others =>
                end case;
            end if;

            if config_done = '1' then
                config_done_reg := '1';
                config_done_irq := '1';
            end if;

            if img_config_done = '1' then
                image_config_done_reg := '1';
                image_config_done_irq := '1';
            end if;

        end if;

        avs_irq <= config_done_irq or image_config_done_irq;
    
    end process;
    
end architecture rtl;