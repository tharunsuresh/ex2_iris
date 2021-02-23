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
use work.vnir_base;

package img_buffer_pkg is
    --Generating 1 buffer for each, allowing for storage of up to 1 row
    constant NUM_SWIR_ROW_FIFO : integer := 1;
    constant NUM_VNIR_ROW_FIFO : integer := 1;

    constant FIFO_WORD_LENGTH : integer := 128;  
    constant FIFO_WORD_BYTES : integer := FIFO_WORD_LENGTH/8;  -- for command creator

    --Number of words in swir and vnir fifo
    constant VNIR_FIFO_DEPTH : integer := 160;  
    constant SWIR_FIFO_DEPTH : integer := 64;   

    --vnir & swir row fragments are split into their respective FIFO word lengths
    subtype row_fragment_t is std_logic_vector (FIFO_WORD_LENGTH-1 downto 0);

    --The links between the vnir and swir fifos
    type vnir_link_a is array (0 to NUM_VNIR_ROW_FIFO-1) of row_fragment_t;
    type swir_link_a is array (0 to NUM_SWIR_ROW_FIFO-1) of row_fragment_t;

    type vnir_row_fragment_a is array (0 to VNIR_FIFO_DEPTH-1) of row_fragment_t;
    type swir_row_fragment_a is array (0 to SWIR_FIFO_DEPTH-1) of row_fragment_t;

    type row_type_buffer_a is array (0 to NUM_VNIR_ROW_FIFO-1) of vnir.row_type_t;

    --vnir pipeline 1st stage
    type row_buffer_a is array (0 to 9) of vnir.row_t;
    type row_ready_buffer_a is array (0 to 9) of vnir.row_type_t;



end package img_buffer_pkg;
