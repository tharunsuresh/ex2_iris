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

entity controller_interface is
    port (
        clock           : in std_logic;
        reset_n         : in std_logic := '0';
        
        avs_address     : in  std_logic_vector(7 downto 0);
        avs_read        : in  std_logic := '0';
        avs_readdata    : out std_logic_vector(31 downto 0);
        avs_write       : in  std_logic := '0';
        avs_writedata   : in  std_logic_vector(31 downto 0);
        avs_irq         : out std_logic;

        avm_address     : out std_logic_vector(7 downto 0);
        avm_read        : out std_logic := '0';
        avm_readdata    : in  std_logic_vector(31 downto 0);
        avm_write       : out std_logic := '0';
        avm_writedata   : out std_logic_vector(31 downto 0);
        avm_irq         : in  std_logic
    );
end entity controller_interface;

architecture rtl of controller_interface is
begin

    avm_address     <= avs_address;
    avm_read        <= avs_read;
    avs_readdata    <= avm_readdata;
    avm_write       <= avs_write;
    avm_writedata   <= avs_writedata;
    avs_irq         <= avm_irq;

end architecture rtl;
