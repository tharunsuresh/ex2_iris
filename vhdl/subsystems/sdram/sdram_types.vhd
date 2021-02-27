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

use work.vnir;

package sdram is
    --An SDRAM Address is a 29 bit signed, any negative addresses are invalid
    constant ADDRESS_LENGTH : integer := 29;
    constant HEADER_LENGTH  : integer := 160;

    --Creating the address type, a signed that shows a invalid address if negative
    subtype address_t is signed (ADDRESS_LENGTH-1 downto 0);
    constant UNDEFINED_ADDRESS : address_t := (ADDRESS_LENGTH-1 => '1', others => '0');

    --A header type that stores the headers as a std_logic_vector
    subtype header_t is std_logic_vector (HEADER_LENGTH-1 downto 0);

    --Address block for the MPU to specify block of changed RAM
    type address_block_t is array (0 to 1) of address_t;
    
    --Enumerators for both the errors and row types
    type error_t is (no_error, full, mpu_check_failed);
    type row_type_t is (ROW_NONE, ROW_BLUE, ROW_RED, ROW_NIR, ROW_SWIR);

    type config_to_sdram_t is record
        memory_base     : address_t;
        memory_bounds   : address_t;
    end record config_to_sdram_t;

    type partition_t is record
        base               : address_t;
        bounds             : address_t;
        fill_bounds        : address_t;
        fill_base          : address_t;
    end record partition_t;

    type memory_state_t is record
        vnir        : partition_t;
        swir        : partition_t;
        vnir_temp   : partition_t;
        swir_temp   : partition_t;
    end record memory_state_t;

    function sdram_type (row_type : in vnir.row_type_t) return row_type_t;
end package sdram;

package body sdram is
    function sdram_type (row_type : in vnir.row_type_t) return row_type_t is
    begin
        case row_type is
            when vnir.ROW_RED =>
                return ROW_RED;
            when vnir.ROW_BLUE =>
                return ROW_BLUE;
            when vnir.ROW_NIR =>
                return ROW_NIR;
            when vnir.ROW_NONE =>
                return ROW_NONE;
        end case;
    end function;
end package body;
