library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.spi_types.all;
use work.avalonmm;
use work.vnir;
use work.swir_types.all;
use work.sdram;
use work.fpga_types.all;

entity partition_register is
    port(
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
        full, bad_mpu_check : out std_logic
    );
end entity partition_register;

architecture rtl of partition_register is
    type state_t is (init, operating);
    signal state, next_state : state_t;

    --This signal allows the register to see what's in the part_out signal
    signal buffer_part : sdram.partition_t;

    --These signals are combinational, and can be written to at any time
    signal buffer_base, buffer_bounds           : sdram.address_t;
    signal buffer_fill_base, buffer_fill_bounds : sdram.address_t;
    signal buffer_img_start, buffer_img_end     : sdram.address_t;

    --A flag saying the partition cannot be added to
    signal no_add, no_sub : std_logic;

    --Checks if the image will overflow the position, returns 1 if it does
    function check_overflow(partition : sdram.partition_t; address_size : sdram.address_t) return std_logic is
    begin
        if (partition.fill_bounds + address_size > partition.bounds) then
            return '1';
        else
            return '0';
        end if;
    end function check_overflow;
    
    --Checks if the image won't fit in the memory because it is too full, returns 1 if it does
    function check_full(partition : sdram.partition_t; address_size : sdram.address_t; start_address : sdram.address_t) return std_logic is
    begin
        if (start_address <= partition.fill_base and start_address + address_size >= partition.fill_base) then
            return '1';
        else
            return '0';
        end if;
    end function check_full;
begin
    --Combinatorial process specifying signal assignments
    state_process : process(state, add_length, sub_length, base, bounds, bounds_write) is
    begin
        case state is
            when init =>
                buffer_base <= base;
                buffer_bounds <= bounds;
                buffer_fill_base <= base;
                buffer_fill_bounds <= base;

                if (bounds_write = '1') then
                    next_state <= operating;
                else
                    next_state <= init;
                end if;

            --When adding stuff to the memory
            when operating =>
                --Some conditional checking to see if the partition can write or not
                if (buffer_part.fill_base <= buffer_part.fill_bounds) then
                    if (check_overflow(buffer_part, add_length) = '1') then
                        if (check_full(buffer_part, add_length, buffer_part.base) = '1') then
                            no_add <= '1';
                        else
                            buffer_fill_bounds <= buffer_part.base + add_length;
                            buffer_img_start <= buffer_part.base;
                            buffer_img_end <= buffer_part.base + add_length;
                        end if;
                    else
                        --No need to check if it's full, the overflow did that already
                        buffer_fill_bounds <= buffer_part.fill_bounds + 1 + add_length;
                        buffer_img_start <= buffer_part.fill_bounds + 1;
                        buffer_img_end <= buffer_part.fill_bounds + 1 + add_length;
                    end if;
                else
                    --Just need to check if it's full for this case
                    if (check_full(buffer_part, add_length, buffer_part.fill_bounds) = '1') then
                        no_add <= '1';
                    else
                        buffer_fill_bounds <= buffer_part.fill_bounds + 1 + add_length;
                        buffer_img_start <= buffer_part.fill_bounds + 1;
                        buffer_img_end <= buffer_part.fill_bounds + 1 + add_length;
                    end if;
                end if;
                
                --Some conditional logic (not as complex) to see whether or not the erase request is good
                if (buffer_part.fill_base + sub_length > buffer_part.fill_bounds) then
                    no_sub <= '1';
                else
                    buffer_fill_base <= buffer_part.fill_base + sub_length;
                end if;

                next_state <= operating;
        end case;
    end process;

    --Assigns outputs at the rising edge of the clock
    sig_assign : process (clk, reset_n) is
    begin
        if (reset_n = '0') then
            --The default undefined address is 0x80000000
            state <= init;
            buffer_part.base        <= sdram.UNDEFINED_ADDRESS;
            buffer_part.bounds      <= sdram.UNDEFINED_ADDRESS;
            buffer_part.fill_base   <= sdram.UNDEFINED_ADDRESS;
            buffer_part.fill_bounds <= sdram.UNDEFINED_ADDRESS;

            part_out.base           <= sdram.UNDEFINED_ADDRESS;
            part_out.bounds         <= sdram.UNDEFINED_ADDRESS;
            part_out.fill_base      <= sdram.UNDEFINED_ADDRESS;
            part_out.fill_bounds    <= sdram.UNDEFINED_ADDRESS;

            img_start               <= sdram.UNDEFINED_ADDRESS;
            img_end                 <= sdram.UNDEFINED_ADDRESS;

            full                    <= '0';
            bad_mpu_check           <= '0';

        elsif rising_edge(clk) then
            state <= next_state;
            full <= '0';
            bad_mpu_check <= '0';

            if (state = init and bounds_write = '1') then
                buffer_part.base        <= buffer_base;
                buffer_part.bounds      <= buffer_bounds;
                buffer_part.fill_base   <= buffer_fill_base;
                buffer_part.fill_bounds <= buffer_fill_bounds;

                part_out.base           <= buffer_base;
                part_out.bounds         <= buffer_bounds;
                part_out.fill_base      <= buffer_fill_base;
                part_out.fill_bounds    <= buffer_fill_bounds;

            elsif (state = operating and filled_add = '1') then
                if (no_add = '1') then
                    full <= '1';
                else
                    part_out.fill_bounds <= buffer_fill_bounds;
                    buffer_part.fill_bounds <= buffer_fill_bounds;

                    img_start <= buffer_img_start;
                    img_end <= buffer_img_end;
                end if;
            
            elsif (state = operating and filled_subtract = '1') then
                if (no_sub = '1') then
                    bad_mpu_check <= '1';
                else
                    part_out.fill_base <= buffer_fill_base;
                    buffer_part.fill_base <= buffer_fill_base;
                end if;
            end if;
        end if;
    end process;
end architecture;