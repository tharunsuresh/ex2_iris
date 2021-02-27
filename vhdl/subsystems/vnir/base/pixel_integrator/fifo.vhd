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

library altera_mf;
use altera_mf.altera_mf_components.all;


entity pixel_integrator_fifo is
generic (
    WORD_SIZE : integer;
    ADDRESS_SIZE : integer
);
port (
    clock           : in std_logic;
    read_data       : out std_logic_vector(WORD_SIZE-1 downto 0);
    read_address    : in std_logic_vector(ADDRESS_SIZE-1 downto 0);
    read_enable     : in std_logic;
    write_data      : in std_logic_vector(WORD_SIZE-1 downto 0);
    write_address   : in std_logic_vector(ADDRESS_SIZE-1 downto 0);
    write_enable    : in std_logic
);
end entity pixel_integrator_fifo;


architecture rtl of pixel_integrator_fifo is
begin

    ram : altsyncram generic map (
        address_aclr_b => "NONE",
        address_reg_b => "CLOCK0",
        clock_enable_input_a => "BYPASS",
        clock_enable_input_b => "BYPASS",
        clock_enable_output_b => "BYPASS",
        intended_device_family => "Cyclone V",
        lpm_type => "altsyncram",
        numwords_a => 2 ** ADDRESS_SIZE,
        numwords_b => 2 ** ADDRESS_SIZE,
        operation_mode => "DUAL_PORT",
        outdata_aclr_b => "NONE",
        power_up_uninitialized => "TRUE",
        rdcontrol_reg_b => "CLOCK0",
        read_during_write_mode_mixed_ports => "DONT_CARE",
        widthad_a => ADDRESS_SIZE,
        widthad_b => ADDRESS_SIZE,
        width_a => WORD_SIZE,
        width_b => WORD_SIZE,
        width_byteena_a => 1
    ) port map (
        address_a => write_address,
        address_b => read_address,
        clock0 => clock,
        data_a => write_data,
        rden_b => read_enable,
        wren_a => write_enable,
        q_b => read_data
    );

end architecture rtl;
