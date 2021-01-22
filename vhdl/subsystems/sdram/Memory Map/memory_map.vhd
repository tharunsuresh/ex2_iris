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
use work.fpga_types.all;

entity memory_map is
    port (
        --Control signals
        clock               : in std_logic;
        reset_n             : in std_logic;

        --SDRAM config signals to and from the FPGA
        config              : in config_to_sdram_t;
        memory_state        : out memory_state_t;

        start_config        : in std_logic;
        config_done         : out std_logic;
        img_config_done     : out std_logic;

        --Image Config signals
        number_swir_rows    : in integer;
        number_vnir_rows    : in integer;

        --Output image row address config
        next_row_type       : in row_type_t;
        next_row_req        : in std_logic;
        output_address      : out address_t;

        --Read data to be read from sdram due to mpu interaction
        sdram_error         : out error_t
    );
end entity memory_map;

architecture rtl of memory_map is
    --FSM signals
    type state_t is (init, idle, img_config_vnir, img_config_swir, imaging);
    signal state, next_state : state_t;

    signal buffer_address : address_t;

    --Creating buffer partitions for the partitions
    signal memory_state_i : memory_state_t;

    --Add/subtract address length signals
    signal vnir_add_length : address_t;
    signal swir_add_length : address_t;
    signal vnir_temp_add_length : address_t;
    signal swir_temp_add_length : address_t;

    signal vnir_sub_length : address_t;
    signal swir_sub_length : address_t;
    signal vnir_temp_sub_length : address_t;
    signal swir_temp_sub_length : address_t;

    --Start addresses for each band for the image
    signal start_blue_address : address_t;
    signal start_red_address  : address_t;
    signal start_nir_address  : address_t;
    signal start_swir_address : address_t;

    signal start_swir_header_address : address_t;
    signal start_vnir_header_address : address_t;

    --Next addresses out of the memory state
    signal next_blue_address : address_t;
    signal next_red_address  : address_t;
    signal next_nir_address  : address_t;
    signal next_swir_address : address_t;

    --Output signal coming from enumerator
    signal inc_blue_address : std_logic;
    signal inc_red_address  : std_logic;
    signal inc_nir_address  : std_logic;
    signal inc_swir_address : std_logic;

    --Various output signals to be Mux'd
    signal row_assign_address : address_t;
    signal img_config_address : address_t;

    --Img write addresses
    signal vnir_img_start : address_t;
    signal vnir_img_end   : address_t;

    signal swir_img_start : address_t;
    signal swir_img_end   : address_t;

    signal vnir_temp_img_start : address_t;
    signal vnir_temp_img_end   : address_t;

    signal swir_temp_img_start : address_t;
    signal swir_temp_img_end   : address_t;

    --Partition error signals
    signal vnir_full : std_logic;
    signal swir_full : std_logic;
    signal vnir_temp_full : std_logic;
    signal swir_temp_full : std_logic;

    signal vnir_bad_mpu_check : std_logic;
    signal swir_bad_mpu_check : std_logic;
    signal vnir_temp_bad_mpu_check : std_logic;
    signal swir_temp_bad_mpu_check : std_logic;

    --State controlling variables
    signal write_addresses  : std_logic;
    signal write_temp_addresses : std_logic;
    signal delete_addresses : std_logic;
    signal no_new_rows      : std_logic;

    signal curr_row_type, prev_row_type : row_type_t;
    signal set_part_bounds : std_logic;

    signal vnir_band_length : address_t;
    signal swir_band_length : address_t;

    --All these are bounds for the partitions
    signal vhdl_base, vhdl_bounds, vhdl_size : address_t;
    signal vnir_base, vnir_bounds : address_t;
    signal swir_base, swir_bounds : address_t;
    signal vnir_temp_base, vnir_temp_bounds : address_t;
    signal swir_temp_base, swir_temp_bounds : address_t;

    --A signal that detects when the addresses should be incremented
    signal inc_flag : std_logic;

    constant VNIR_ROW_LENGTH : integer := 1280; --2048 px/row * 10 b/px / 16 b/address = 1280 address/row
    constant SWIR_ROW_LENGTH : integer := 512;  -- 512 px/row * 16 b/px / 16 b/address = 512 address/row
    constant HEADER_LENGTH   : integer := 16;   -- 160 b/header         / 16 b/address = 16 address/header

    component edge_detector is
        generic(fall_edge : boolean := false);
        port(
            clk         : in std_logic;
            reset_n     : in std_logic;
    
            ip          : in std_logic;
            edge_flag   : out std_logic
        );
    end component edge_detector;

    component address_counter is
        generic(increment_size : integer);
        port(
            clk             : in std_logic;
            start_address   : in address_t;
            inc_flag        : in std_logic;
            
            output_address  : out address_t
        );
    end component address_counter;

    component partition_register is
        port(
        clk, reset_n, bounds_write, filled_add, filled_subtract : in std_logic;
        base, bounds, add_length, sub_length : in address_t;
        part_out : out partition_t;
        img_start, img_end : out address_t;
        full, bad_mpu_check : out std_logic
        );
    end component partition_register;

begin
    --Process responsible assigning the next state at the rising edge
    op_sig_assign : process(clock) is
    begin
        if (reset_n = '0') then
            state <= init;
            output_address <= UNDEFINED_ADDRESS;

            config_done <= '0';
            img_config_done <= '0';
            
        elsif rising_edge(clock) then
            state <= next_state;
            output_address <= buffer_address;

            case state IS
                when init =>
                    config_done <= '0';
                    img_config_done <= '0';

                when idle =>
                    config_done <= '1';
                    img_config_done <= '0';
                
                when img_config_vnir =>
                    config_done <= '1';
                    img_config_done <= '1';
                
                when img_config_swir =>
                    config_done <= '1';
                    img_config_done <= '1';

                when imaging =>
                    config_done <= '1';
                    img_config_done <= '1';
            end case;
        end if;
    end process;

    --Process responsible for assigning the appropriate state
    state_machine : process(start_config, inc_flag, write_addresses, no_new_rows) is
    begin
        case state is
            when init =>
                if (start_config = '1') then
                    next_state <= idle;
                else
                    next_state <= init;
                end if;
            when idle =>
                if (write_addresses = '1') then
                    next_state <= img_config_vnir;
                else
                    next_state <= idle;
                end if;
            when img_config_vnir =>
                if (inc_flag = '1') then
                    next_state <= img_config_swir;
                else
                    next_state <= img_config_vnir;
                end if;
            when img_config_swir =>
                if (inc_flag = '1') then
                    next_state <= imaging;
                else
                    next_state <= img_config_swir;
                end if;
            when imaging =>
                if (no_new_rows = '1') then
                    next_state <= idle;
                else
                    next_state <= imaging;
                end if;
        end case;
    end process;

    internal_sync_registers : process (clock, reset_n) is
    begin
        if (reset_n = '0') then
            --Reseting everything
            vnir_band_length <= UNDEFINED_ADDRESS;
            swir_band_length <= UNDEFINED_ADDRESS;

            vnir_add_length <= UNDEFINED_ADDRESS;
            swir_add_length <= UNDEFINED_ADDRESS;
            vnir_temp_add_length <= UNDEFINED_ADDRESS;
            swir_temp_add_length <= UNDEFINED_ADDRESS;

            set_part_bounds <= '0';

        elsif rising_edge(clock) then
            write_addresses <= '0';
            set_part_bounds <= '0';

            inc_nir_address <= '0';
            inc_red_address <= '0';
            inc_blue_address <= '0';
            inc_swir_address <= '0';

            case state is
                --Init stores the full vhdl partition bounds
                when init =>
                    if (start_config = '1') then
                        set_part_bounds <= '1';
                        vhdl_base <= config.memory_base;
                        vhdl_bounds <= config.memory_bounds;
                    end if;

                when idle =>
                    --Setting the image boundaries
                    if (number_vnir_rows > 0 and number_swir_rows > 0 and vnir_band_length = UNDEFINED_ADDRESS) then
                        vnir_band_length <= to_signed(number_vnir_rows * VNIR_ROW_LENGTH, ADDRESS_LENGTH);
                        swir_band_length <= to_signed(number_swir_rows * SWIR_ROW_LENGTH, ADDRESS_LENGTH);
        
                        vnir_add_length <= to_signed(number_vnir_rows * VNIR_ROW_LENGTH * 3 + 16, ADDRESS_LENGTH);
                        swir_add_length <= to_signed(number_swir_rows * SWIR_ROW_LENGTH + 16, ADDRESS_LENGTH);
        
                        write_addresses <= '1';
                    end if;
                
                --Img_config_vnir sets the band length
                when img_config_vnir => null;

                when img_config_swir => null;
                
                when imaging =>
                    if (inc_flag = '1') then
                        case prev_row_type is
                            when ROW_NIR => inc_nir_address <= '1';
                            when ROW_RED => inc_red_address <= '1';
                            when ROW_BLUE => inc_blue_address <= '1';
                            when ROW_SWIR => inc_swir_address <= '1';
                            when ROW_NONE => null;
                        end case;
                    end if;
            end case;

            if (next_row_type /= ROW_NONE and next_row_req = '1') then
                prev_row_type <= curr_row_type;
                curr_row_type <= next_row_type;
            end if;
        end if;
    end process;

    next_row_edge : edge_detector generic map (false) port map (clock, reset_n, next_row_req, inc_flag);

    --Address counters for each band
    blue_row_counter : address_counter
        generic map(increment_size => VNIR_ROW_LENGTH)
        port map(
            clk => clock,
            start_address => start_blue_address,
            inc_flag => inc_blue_address,
            output_address => next_blue_address
        );

    red_row_counter : address_counter
        generic map(increment_size => VNIR_ROW_LENGTH)
        port map(
            clk => clock,
            start_address => start_red_address,
            inc_flag => inc_red_address,
            output_address => next_red_address
        );

    nir_row_counter : address_counter
        generic map(increment_size => VNIR_ROW_LENGTH)
        port map(
            clk => clock,
            start_address => start_nir_address,
            inc_flag => inc_nir_address,
            output_address => next_nir_address
        );

    swir_row_counter : address_counter
        generic map(increment_size => SWIR_ROW_LENGTH)
        port map(
            clk => clock,
            start_address => start_swir_address,
            inc_flag => inc_swir_address,
            output_address => next_swir_address
        );

    --Creating partitions for each type of memory
    vnir_partition_register : partition_register
        port map(
            clk => clock,
            reset_n => reset_n,

            bounds_write => set_part_bounds,
            filled_add => write_addresses,
            filled_subtract => delete_addresses,

            base => vnir_base,
            bounds => vnir_bounds,
            add_length => vnir_add_length,
            sub_length => vnir_sub_length,

            part_out => memory_state_i.vnir,

            img_start => vnir_img_start,
            img_end => vnir_img_end,

            full => vnir_full,
            bad_mpu_check => vnir_bad_mpu_check
        );
    
    swir_partition_register : partition_register
        port map(
            clk => clock,
            reset_n => reset_n,

            bounds_write => set_part_bounds,
            filled_add => write_addresses,
            filled_subtract => delete_addresses,

            base => swir_base,
            bounds => swir_bounds,
            add_length => swir_add_length,
            sub_length => swir_sub_length,

            part_out => memory_state_i.swir,
            
            img_start => swir_img_start,
            img_end => swir_img_end,

            full => swir_full,
            bad_mpu_check => swir_bad_mpu_check
        );
    
    vnir_temp_partition_register : partition_register
        port map(
            clk => clock,
            reset_n => reset_n,

            bounds_write => set_part_bounds,
            filled_add => write_temp_addresses,
            filled_subtract => delete_addresses,

            base => vnir_temp_base,
            bounds => vnir_temp_bounds,
            add_length => vnir_temp_add_length,
            sub_length => vnir_temp_sub_length,

            part_out => memory_state_i.vnir_temp,

            img_start => vnir_temp_img_start,
            img_end => vnir_temp_img_end,

            full => vnir_temp_full,
            bad_mpu_check => vnir_temp_bad_mpu_check
        );
        
    swir_temp_partition_register : partition_register
        port map(
            clk => clock,
            reset_n => reset_n,

            bounds_write => set_part_bounds,
            filled_add => write_temp_addresses,
            filled_subtract => delete_addresses,

            base => swir_temp_base,
            bounds => swir_temp_bounds,
            add_length => swir_temp_add_length,
            sub_length => swir_temp_sub_length,

            part_out => memory_state_i.swir_temp,

            img_start => swir_temp_img_start,
            img_end => swir_temp_img_end,

            full => swir_temp_full,
            bad_mpu_check => swir_temp_bad_mpu_check
        );
    
    --Detailing the math behind the partition boundaries
    vhdl_size        <= vhdl_bounds - vhdl_base;
    vnir_base        <= vhdl_base;
    vnir_bounds      <= resize(vhdl_size * 8 / 16 + vhdl_base, ADDRESS_LENGTH);
    swir_base        <= resize(vhdl_size * 8 / 16 + 1 + vhdl_base, ADDRESS_LENGTH);
    swir_bounds      <= resize(vhdl_size * 14 / 16 + vhdl_base, ADDRESS_LENGTH);
    vnir_temp_base   <= resize(vhdl_size * 14 / 16 + 1 + vhdl_base, ADDRESS_LENGTH);
    vnir_temp_bounds <= resize(vhdl_size * 15 / 16 + vhdl_base, ADDRESS_LENGTH);
    swir_temp_base   <= resize(vhdl_size * 15 / 16 + 1 + vhdl_base, ADDRESS_LENGTH);
    swir_temp_bounds <= vhdl_size + vhdl_base;

    --Mapping the memory state to match the buffer parts out of the partition components
    memory_state <= memory_state_i;

    sdram_error <= full             when (vnir_full = '1' or swir_full = '1' or vnir_temp_full = '1' or swir_temp_full = '1') else
                   mpu_check_failed when (vnir_bad_mpu_check = '1' or swir_bad_mpu_check = '1' or vnir_temp_bad_mpu_check = '1' or swir_temp_bad_mpu_check = '1') else
                   no_error;

    --Creating the start addresses for each counter
    start_swir_header_address <= swir_img_start;
    start_vnir_header_address <= vnir_img_start;

    start_blue_address <= vnir_img_start + HEADER_LENGTH;
    start_red_address  <= vnir_img_start + HEADER_LENGTH + vnir_band_length; --Adding room for the blue band
    start_nir_address  <= resize(vnir_img_start + HEADER_LENGTH + vnir_band_length * 2, ADDRESS_LENGTH); --Room for both blue and red
    start_swir_address <= swir_img_start + HEADER_LENGTH;
    
    no_new_rows <= '1' when (next_blue_address = start_red_address and next_red_address = start_nir_address and next_nir_address = vnir_img_end and next_swir_address = swir_img_end) else '0';

    with curr_row_type select row_assign_address <=
        next_swir_address when ROW_SWIR,
        next_nir_address  when  ROW_NIR,
        next_red_address  when  ROW_RED,
        next_blue_address when ROW_BLUE,
        UNDEFINED_ADDRESS when ROW_NONE;

    img_config_address <= vnir_img_start when state = img_config_vnir else
                          swir_img_start when state = img_config_swir else
                          UNDEFINED_ADDRESS;  
    
    buffer_address <= row_assign_address when state = imaging else
                      img_config_address when state = img_config_vnir or state = img_config_swir else
                      UNDEFINED_ADDRESS;    
    
end architecture;