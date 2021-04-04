library ieee;
use ieee.std_logic_1164.all;

entity edge_detector is
    generic(fall_edge : boolean := false);
    port(
        clk         : in std_logic;
        reset_n     : in std_logic;

        ip          : in std_logic;
        edge_flag   : out std_logic
    );
end entity edge_detector;

architecture rtl of edge_detector is
    signal prev_ip : std_logic;
    signal curr_ip  : std_logic;
begin
    --storing inputs
    ip_states : process(clk) is
    begin
        if (reset_n = '0') then
            prev_ip <= '0';
            curr_ip <= '0';
        elsif rising_edge(clk) then
            prev_ip <= curr_ip;
            curr_ip <= ip;
        end if;
    end process;

    --If fall_edge is on, find falling edge
    edge_flag <= (not(curr_ip) and prev_ip) when fall_edge else
                 (curr_ip and not(prev_ip));
end architecture;    