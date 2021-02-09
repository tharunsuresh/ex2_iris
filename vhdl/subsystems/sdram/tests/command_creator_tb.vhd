library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.avalonmm;
use work.vnir;
use work.sdram;

use work.img_buffer_pkg.all;
use work.swir_types.all;
use work.fpga_types.all;

entity command_creator_tb is
end entity command_creator_tb;

architecture behavioral of command_creator_tb is
    

   signal clock             : std_logic := '0';
   signal reset_n           : std_logic := '0';
   signal vnir_img_header   : sdram.header_t;
   signal swir_img_header   : sdram.header_t;
   signal row_data          : row_fragment_t;
   signal row_type          : sdram.row_type_t;
   signal address           : sdram.address_t;
   signal buffer_transmitting : std_logic;
   signal next_row_req      : std_logic;
   signal sdram_busy        : std_logic;
   signal sdram_avalon_out  : avalonmm.from_master_t;
   signal sdram_avalon_in   : avalonmm.to_master_t;

begin

    main_inst: entity work.command_creator 
    port map (
        clock               => clock,
        reset_n             => reset_n,
        vnir_img_header     => vnir_img_header,
        swir_img_header     => swir_img_header,
        row_data            => row_data,
        row_type            => row_type,
        address             => address,
        buffer_transmitting => buffer_transmitting,
        next_row_req        => next_row_req,
        sdram_busy          => sdram_busy,
        sdram_avalon_out    => sdram_avalon_out,
        sdram_avalon_in     => sdram_avalon_in
    );
    
    reset_process: process
    begin
        reset_n <= '0';
        wait for 50 ns; 
        reset_n <= '1';
        wait;
    end process reset_process;
                                      
    clock <= NOT clock after 10 ns; 
    
    data_process: process
    begin
        buffer_transmitting <= '0';
        wait for 100 ns; 
            
        row_data <= (others => '0');
        buffer_transmitting <= '0';
        if next_row_req = '1' then
            for i in 0 to SWIR_FIFO_DEPTH loop
                buffer_transmitting <= next_row_req;
                row_data            <= std_logic_vector(to_unsigned(i, FIFO_WORD_LENGTH));
                wait for 20 ns;
            end loop;
            buffer_transmitting <= '0';
        end if;
    
        wait; 

    end process data_process;

    address <= (others => '0');
    sdram_avalon_in.wait_request <= '0';

    

end architecture behavioral;
