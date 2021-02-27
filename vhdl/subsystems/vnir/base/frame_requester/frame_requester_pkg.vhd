library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pulse_generator_pkg;


package frame_requester_pkg is

    type config_t is record
        num_frames      : integer;
        frame_clocks    : integer;
        exposure_clocks : integer;
    end record config_t;

    type state_t is (IDLE, IMAGING);

    type status_t is record
        state           : state_t;
        frame_request   : pulse_generator_pkg.status_t;
        exposure_start  : pulse_generator_pkg.status_t;
    end record status_t;

end package frame_requester_pkg;
