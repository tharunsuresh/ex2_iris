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

library work;
use work.sdram;
use work.img_buffer_pkg;

package avalonmm is

    type from_master_t is record
        address     : std_logic_vector(sdram.ADDRESS_LENGTH-1 downto 0);
        burst_count : std_logic_vector(6 downto 0);
        write_data  : std_logic_vector(img_buffer_pkg.FIFO_WORD_LENGTH-1 downto 0);
        byte_enable : std_logic_vector(img_buffer_pkg.FIFO_WORD_BYTES-1 downto 0); --9 downto 0 if 80 --15 downto 0 if 128
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package spi_types is

    type spi_from_master_t is record
        clock        : std_logic;
        slave_select : std_logic;
        data         : std_logic;
    end record spi_from_master_t;

    type spi_to_master_t is record
        data : std_logic;
    end record spi_to_master_t;

    type spi_t is record
        from_master : spi_from_master_t;
        to_master   : spi_to_master_t;
    end record spi_t;

end package spi_types;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package logic_types is

    subtype logic1_t is std_logic_vector(1-1 downto 0);
    subtype logic2_t is std_logic_vector(2-1 downto 0);
    subtype logic3_t is std_logic_vector(3-1 downto 0);
    subtype logic4_t is std_logic_vector(4-1 downto 0);
    subtype logic5_t is std_logic_vector(5-1 downto 0);
    subtype logic6_t is std_logic_vector(6-1 downto 0);
    subtype logic7_t is std_logic_vector(7-1 downto 0);
    subtype logic8_t is std_logic_vector(8-1 downto 0);
    subtype logic15_t is std_logic_vector (15-1 downto 0);
    subtype logic16_t is std_logic_vector(16-1 downto 0);
    type logic16_vector_t is array(integer range <>) of logic16_t;

    pure function to_logic1(i : integer) return logic1_t;
    pure function to_logic2(i : integer) return logic2_t;
    pure function to_logic3(i : integer) return logic3_t;
    pure function to_logic4(i : integer) return logic4_t;
    pure function to_logic5(i : integer) return logic5_t;
    pure function to_logic6(i : integer) return logic6_t;
    pure function to_logic7(i : integer) return logic7_t;
    pure function to_logic8(i : integer) return logic8_t;
    pure function to_logic15(i : integer) return logic15_t;
    pure function to_logic16(i : integer) return logic16_t;

    pure function bitwise_contains(flags : std_logic_vector; flag : std_logic_vector) return boolean;

end package logic_types;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;


package body logic_types is

    pure function to_logic1(i : integer) return logic1_t is
    begin
        return std_logic_vector(to_unsigned(i, 1));
    end function to_logic1;

    pure function to_logic2(i : integer) return logic2_t is
    begin
        return std_logic_vector(to_unsigned(i, 2));
    end function to_logic2;

    pure function to_logic3(i : integer) return logic3_t is
    begin
        return std_logic_vector(to_unsigned(i, 3));
    end function to_logic3;
    
    pure function to_logic4(i : integer) return logic4_t is
    begin
        return std_logic_vector(to_unsigned(i, 4));
    end function to_logic4;

    pure function to_logic5(i : integer) return logic5_t is
    begin
        return std_logic_vector(to_unsigned(i, 5));
    end function to_logic5;

    pure function to_logic6(i : integer) return logic6_t is
    begin
        return std_logic_vector(to_unsigned(i, 6));
    end function to_logic6;

    pure function to_logic7(i : integer) return logic7_t is
    begin
        return std_logic_vector(to_unsigned(i, 7));
    end function to_logic7;

    pure function to_logic8(i : integer) return logic8_t is
    begin
        return std_logic_vector(to_unsigned(i, 8));
    end function to_logic8;
    
    pure function to_logic15(i : integer) return logic15_t is
    begin
        return std_logic_vector(to_unsigned(i, 15));
    end function to_logic15;

    pure function to_logic16(i : integer) return logic16_t is
    begin
        return std_logic_vector(to_unsigned(i, 16));
    end function to_logic16;

    pure function bitwise_contains(flags : std_logic_vector; flag : std_logic_vector) return boolean is
    begin
        return or_reduce(flags and flag) = '1';
    end function bitwise_contains;

end package body logic_types;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;


package integer_types is

    type integer_vector_t is array(integer range <>) of integer;

    pure function min_2(a : integer; b : integer) return integer;
    pure function min_n(v : integer_vector_t) return integer;
    pure function max_2(a : integer; b : integer) return integer;
    pure function max_n(v : integer_vector_t) return integer;
    pure function zeros(length : integer) return integer_vector_t;
    
    pure function popcount(u : unsigned) return integer;
    pure function is_power_of_2(i : integer) return boolean;

    procedure increment_rollover(
        i : inout integer;
        threshold : integer;
        enable : boolean;
        rolled_over : out boolean
    );

    procedure increment(
        i : inout integer;
        enable : boolean
    );

end package integer_types;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


package body integer_types is

    pure function min_2(a : integer; b : integer) return integer is
    begin
        if a < b then return a; else return b; end if;
    end function min_2;

    pure function min_n(v : integer_vector_t) return integer is
        variable ret : integer;
    begin
        ret := v(v'left);
        for i in v'range loop
            ret := min_2(ret, v(i));
        end loop;
        return ret;
    end function min_n;

    pure function max_2(a : integer; b : integer) return integer is
    begin
        if a > b then return a; else return b; end if;
    end function max_2;

    pure function max_n(v : integer_vector_t) return integer is
        variable ret : integer;
    begin
        ret := v(v'left);
        for i in v'range loop
            ret := max_2(ret, v(i));
        end loop;
        return ret;
    end function max_n;

    pure function zeros(length : integer) return integer_vector_t is
    begin
        return (length-1 downto 0 => 0);
    end function zeros;

    procedure increment_rollover(
        i : inout integer;
        threshold : integer;
        enable : boolean;
        rolled_over : out boolean
    ) is
    begin
        if enable then
            if i + 1 < threshold then
                i := i + 1;
                rolled_over := false;
            else
                i := 0;
                rolled_over := true;
            end if;
        end if;
    end procedure increment_rollover;

    procedure increment(
        i : inout integer;
        enable : boolean
    ) is
    begin
        if enable then
            i := i + 1;
        end if;
    end procedure increment;

    pure function popcount(u : unsigned) return integer is
        variable n : integer := 0;
    begin
        for i in u'range loop
            if u(i) = '1' then
                n := n + 1;
            end if;
        end loop;
        return n;
    end function popcount;

    pure function is_power_of_2(i : integer) return boolean is
    begin
        return popcount(to_unsigned(i, 32)) = 1;
    end function is_power_of_2;

end package body integer_types;



library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package unsigned_types is

    subtype u64 is unsigned(63 downto 0);

    pure function to_u64(bits : std_logic_vector) return u64;
    pure function to_u64(u : unsigned) return u64;
    pure function to_u64(i : integer) return u64;
    pure function to_u64(r : real) return u64;
    pure function to_unsigned(u : u64; bits : integer) return unsigned;

end package unsigned_types;


library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;


package body unsigned_types is

    pure function to_u64(bits : std_logic_vector) return u64 is
    begin
        return to_u64(unsigned(bits));
    end function to_u64;

    pure function to_u64(u : unsigned) return u64 is
    begin
        return u64(resize(u, 64));
    end function to_u64;

    pure function to_u64(i : integer) return u64 is
    begin
        return u64(to_unsigned(i, 64));
    end function to_u64;

    pure function to_u64(r : real) return u64 is
    begin
        return to_u64(to_unsigned(natural(r), 64));
    end function to_u64;

    pure function to_unsigned(u : u64; bits : integer) return unsigned is
    begin
        return resize(unsigned(u), bits);
    end function to_unsigned;

end package body unsigned_types;
