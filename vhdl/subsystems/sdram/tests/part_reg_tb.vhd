library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.spi_types.all;
use work.avalonmm;
use work.vnir;
use work.swir_types.all;
use work.sdram;
use work.fpga.all;

entity part_reg_tb is
end entity;

architecture sim of part_reg_tb is
    constant clk_freq : integer := 20000000;
    constant clk_period : time := 1000 ms / clk_freq;

    signal clk : std_logic := '0';
    signal reset_n : std_logic := '0';

    signal bounds_write, filled_add, filled_subtract : std_logic := '0';
    signal base, bounds, add_length, sub_length : sdram.address_t := (others => '0');

    signal partition : sdram.partition_t;

    signal img_start, img_end : sdram.address_t;
    signal full, bad_mpu_check : std_logic;

    component partition_register is port(
        --Control signals
        clk, reset_n : in std_logic;

        --Enable signal for writing to both bounds and filled bounds
        bounds_write, filled_add, filled_subtract : in std_logic;

        --Values to write
        base, bounds, add_length, sub_length : in sdram.address_t;

        --Partition read from the register
        part_out : out sdram.partition_t;

        --Unsigneds representing the new image
        img_start, img_end : out sdram.address_t;

        --Error signals
        full, bad_mpu_check : out std_logic);
    end component;
begin
    part_reg : partition_register port map(clk, reset_n, bounds_write, filled_add, filled_subtract, base, bounds, add_length, sub_length, partition, img_start, img_end, full, bad_mpu_check);
    process is
    begin
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        reset_n <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        base <= to_signed(16#400#, sdram.ADDRESS_LENGTH);
        bounds <= to_signed(16#1600#, sdram.ADDRESS_LENGTH);
        wait until rising_edge(clk);
        bounds_write <= '1';
        wait until rising_edge(clk);
        base <= to_signed(16#600#, sdram.ADDRESS_LENGTH);
        bounds <= to_signed(16#800#, sdram.ADDRESS_LENGTH);
        wait until rising_edge(clk);
        bounds_write <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        add_length <= to_signed(16#600#, sdram.ADDRESS_LENGTH);
        filled_add <= '1';
        wait until rising_edge(clk);
        filled_add <= '0';
        wait until rising_edge(clk);
        add_length <= to_signed(16#400#, sdram.ADDRESS_LENGTH);
        filled_add <= '1';
        wait until rising_edge(clk);
        filled_add <= '0';
        wait until rising_edge(clk);
        sub_length <= to_signed(16#500#, sdram.ADDRESS_LENGTH);
        filled_subtract <= '1';
        wait until rising_edge(clk);
        filled_subtract <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        sub_length <= to_signed(16#800#, sdram.ADDRESS_LENGTH);
        wait until rising_edge(clk);
        filled_subtract <= '1';
        wait until rising_edge(clk);
        filled_subtract <= '0';
        
        

    end process;

    clk <= not(clk) after clk_period / 2;
end architecture;
