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

use work.vnir_base.all;
use work.integer_types.all;

package pixel_integrator_pkg is
    constant MAX_N_WINDOWS : integer := 10;

    type config_t is record
        windows : window_vector_t(MAX_N_WINDOWS-1 downto 0);
        length : integer;
    end record config_t;

    type edge_type_t is (INTERIOR, LEADING, LAGGING);

    type fragment_idx_t is record
        x           : integer;
        i_fragment  : integer;
        i_window    : integer;
        is_leading  : boolean;
        is_lagging  : boolean;
    end record fragment_idx_t;

    type status_t is record
        fragment_available  : std_logic;
        fragment_x          : integer;
    end record status_t;

    -- Like pixel_vector_t, but stores std_logic_vectors
    type lpixel_vector_t is array(integer range <>) of std_logic_vector;

    pure function sizes(windows : window_vector_t) return integer_vector_t;

    pure function to_pixels(lpixels : lpixel_vector_t) return pixel_vector_t;
    pure function to_lpixels(pixels : pixel_vector_t) return lpixel_vector_t;

    pure function resize_pixels(pixels : pixel_vector_t; new_size : integer) return pixel_vector_t;
    -- Allow pixel-wise summing of pixel vectors
    pure function "+" (lhs : pixel_vector_t; rhs : pixel_vector_t) return pixel_vector_t;
    
    -- Synthesizable version of:
    --
    --       to_unsigned(floor(log2(real(u))), u'length)
    --
    -- Works by finding the index of the MSB
    pure function log2_floor(u : unsigned) return unsigned;
    -- Synthesizable single-cycle division for when `rhs` is a power of
    -- 2. Works by shifting `lhs` according to `log2(rhs)`
    pure function shift_divide(lhs : unsigned; rhs : unsigned) return unsigned;
    -- Divides a pixel vector by a power of 2
    pure function shift_divide(lhs : pixel_vector_t; rhs : unsigned) return pixel_vector_t;

end package pixel_integrator_pkg;

package body pixel_integrator_pkg is

    pure function sizes(windows : window_vector_t) return integer_vector_t is
        variable sizes : integer_vector_t(windows'range);
    begin
        for i in windows'range loop
            sizes(i) := size(windows(i));
        end loop;
        return sizes;
    end function sizes;

    pure function to_pixels(lpixels : lpixel_vector_t) return pixel_vector_t is
        variable pixels : pixel_vector_t(lpixels'range)(lpixels(0)'range);
    begin
        for i in pixels'range loop
            pixels(i) := unsigned(lpixels(i));
        end loop;
        return pixels;
    end function to_pixels;

    pure function to_lpixels(pixels : pixel_vector_t) return lpixel_vector_t is
        variable lpixels : lpixel_vector_t(pixels'range)(pixels(0)'range);
    begin
        for i in lpixels'range loop
            lpixels(i) := std_logic_vector(pixels(i));
        end loop;
        return lpixels;
    end function to_lpixels;

    pure function resize_pixels(pixels : pixel_vector_t; new_size : integer) return pixel_vector_t is
        variable re : pixel_vector_t(pixels'range)(new_size-1 downto 0);
    begin
        for i_pixel in pixels'range loop
            re(i_pixel) := resize(pixels(i_pixel), new_size);
        end loop;
        return re;
    end function resize_pixels;

    pure function "+" (lhs : pixel_vector_t; rhs : pixel_vector_t) return pixel_vector_t is
        variable sum : pixel_vector_t(rhs'range)(rhs(0)'range);
    begin
        for i in lhs'range loop
            sum(i) := lhs(i) + rhs(i);
        end loop;
        return sum;
    end function "+";

    pure function to_address(i : integer; ADDRESS_BITS : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(i, ADDRESS_BITS));
    end function to_address;

    pure function log2_floor(u : unsigned) return unsigned is
        variable result : unsigned(u'range);
    begin
        for i in 0 to u'length-1 loop
            if u(i) then
                result := to_unsigned(i, result'length);
            end if;
        end loop;
        return result;
    end function log2_floor;

    pure function shift_divide(lhs : unsigned; rhs : unsigned) return unsigned is
        variable quotient : unsigned(lhs'range);
    begin
        assert is_power_of_2(to_integer(rhs));
        quotient := shift_right(lhs, to_integer(log2_floor(rhs)));
        return quotient;
    end function shift_divide;

    pure function shift_divide(lhs : pixel_vector_t; rhs : unsigned) return pixel_vector_t is
        variable quotient : pixel_vector_t(lhs'range)(lhs(0)'range);
    begin
        for i in lhs'range loop
            quotient(i) := pixel_t(shift_divide(unsigned(lhs(i)), rhs));
        end loop;
        return quotient;
    end function shift_divide;

end package body pixel_integrator_pkg;
