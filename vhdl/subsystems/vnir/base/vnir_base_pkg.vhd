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

use work.logic_types.all;


-- Contains types used internally in the VNIR sensor subsystem.
-- 
-- Uses unconstrained arrays for maximum flexibility. Note that this
-- means all internal VNIR sensor subsystem components must be able
-- to work with arbitrary pixel sizes/etc.
package vnir_base is

    subtype pixel_t is unsigned;
    type pixel_vector_t is array(integer range <>) of pixel_t;

    type window_t is record
        lo  : integer;
        hi  : integer;
    end record window_t;
    type window_vector_t is array(integer range <>) of window_t;
    
    -- VNIR sensor calibration values
    type calibration_t is record
        v_ramp1  : integer;
        v_ramp2  : integer;
        offset   : integer;
        adc_gain : integer;
    end record calibration_t;

    -- VNIR sensor control byte
    type control_t is record
        dval : std_logic;
        lval : std_logic;
        fval : std_logic;
        slot : std_logic;
        row : std_logic;
        fot : std_logic;
        inte1 : std_logic;
        inte2 : std_logic;
    end record control_t;

    pure function size(window : window_t) return integer;
    pure function total_rows (windows : window_vector_t) return integer;
    pure function to_control (ctrl_bits : std_logic_vector) return control_t;
    pure function to_logic8 (control : control_t) return logic8_t;

end package vnir_base;


package body vnir_base is
    pure function size(window : window_t) return integer is
    begin
        return window.hi - window.lo + 1;
    end function size;

    pure function total_rows (windows : window_vector_t) return integer is
        variable sum : integer := 0;
    begin
        for i in windows'range loop
            sum := sum + size(windows(i));
        end loop;
        return sum;
    end function total_rows;

    pure function to_control (ctrl_bits : std_logic_vector) return control_t is
    begin
        return (
            dval => ctrl_bits(ctrl_bits'low + 0),
            lval => ctrl_bits(ctrl_bits'low + 1),
            fval => ctrl_bits(ctrl_bits'low + 2),
            slot => ctrl_bits(ctrl_bits'low + 3),
            row => ctrl_bits(ctrl_bits'low + 4),
            fot => ctrl_bits(ctrl_bits'low + 5),
            inte1 => ctrl_bits(ctrl_bits'low + 6),
            inte2 => ctrl_bits(ctrl_bits'low + 7)
        );
    end function to_control;

    pure function to_logic8 (control : control_t) return logic8_t is
    begin
        return (
            0 => control.dval,
            1 => control.lval,
            2 => control.fval,
            3 => control.slot,
            4 => control.row,
            5 => control.fot,
            6 => control.inte1,
            7 => control.inte2,
            others => '0'
        );
    end function to_logic8;

end package body vnir_base;
