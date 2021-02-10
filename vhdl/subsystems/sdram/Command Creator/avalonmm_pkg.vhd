library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.sdram;
use work.img_buffer_pkg;

package avalonmm is

    type from_master_t is record
        address     : std_logic_vector(sdram.ADDRESS_LENGTH-1 downto 0);
        burst_count : std_logic_vector(8 downto 0);
        write_data  : std_logic_vector(img_buffer_pkg.FIFO_WORD_LENGTH-1 downto 0);
        byte_enable : std_logic_vector(img_buffer_pkg.FIFO_WORD_BYTES-1 downto 0);
        write_cmd   : std_logic;
    end record from_master_t;

    type to_master_t is record
        wait_request    : std_logic;
    end record to_master_t;

    type bus_t is record
        from_master : from_master_t;
        to_master   : to_master_t;
    end record bus_t;

end package avalonmm;
