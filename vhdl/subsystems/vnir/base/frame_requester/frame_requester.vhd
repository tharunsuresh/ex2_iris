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

use work.frame_requester_pkg.all;

-- Controls the VNIR sensor in external-exposure mode using the sensor's
-- frame_request and exposure_start inputs.
--
-- The control i/o of `frame_requester` are in the main clock domain,
-- with the sensor interface being in the sensor clock domain.
--
-- `frame_requester` is configured by setting the desired fps, exposure
-- time and frame count in its `config` input, then asserting
-- `start_config` for a single clock cycle. When configuration is
-- finished, `config_done` will be held high for a single clock cycle.
-- 
-- Once configured, a sequence of frame requests may be triggerd by
-- setting `do_imaging` high for a single clock cycle. After it requests
-- the desired number of frames, `frame_requester` holds `imaging_done`
-- high for a single clock cycle to indicate that it has finished.
--
-- The frame requester assumes the sensor is configured in external
-- exposure mode. In this mode, to capture a frame, the `exposure_start`
-- input to the sensor must be pulsed, then after the desired exposure
-- time (minus a fixed offset), `frame_request` must be pulsed to
-- request the exposure stop and the sensor data be read out.
--
-- `frame_requester` is a wrapper for `frame_requester_mainclock`, which
-- operates entirely in the main clock domain. `frame_requester`
-- translates the sensor input signals (`frame_request` and
-- `exposure_start`) to the sensor clock domain.
entity frame_requester is
generic (
    FRAGMENT_WIDTH      : integer;
    CLOCKS_PER_SEC      : integer
);
port (
    -- Interface w/ subsystems is clocked on the main clock
    clock               : in std_logic;
    reset_n             : in std_logic;

    config              : in config_t;
    start_config        : in std_logic;
    config_done         : out std_logic;
    
    do_imaging          : in std_logic;
    imaging_done        : out std_logic;

    status              : out status_t;
    
    -- Interface w/ sensor is clocked on the sensor clock
    sensor_clock        : in std_logic;
    frame_request       : out std_logic;
    exposure_start      : out std_logic
);
end entity frame_requester;

architecture rtl of frame_requester is

    component frame_requester_mainclock is
    generic (
        FRAGMENT_WIDTH      : integer := FRAGMENT_WIDTH;
        CLOCKS_PER_SEC      : integer := CLOCKS_PER_SEC
    );
    port (
        clock               : in std_logic;
        reset_n             : in std_logic;
        config              : in config_t;
        start_config        : in std_logic;
        config_done         : out std_logic;
        do_imaging          : in std_logic;
        imaging_done        : out std_logic;
        frame_request       : out std_logic;
        exposure_start      : out std_logic;
        status              : out status_t
    );
    end component frame_requester_mainclock;

    component clock_bridge is
    port (
        reset_n   : in std_logic;
        i_clock   : in std_logic;
        i         : in std_logic;
        o_clock   : in std_logic;
        o         : out std_logic
    );
    end component clock_bridge;

    signal frame_request_mainclock  : std_logic;
    signal exposure_start_mainclock : std_logic;
    
begin

    frame_requester_mainclock_cmp : frame_requester_mainclock port map (
        clock => clock,
        reset_n => reset_n,
        
        config => config,
        start_config => start_config,
        config_done => config_done,
        
        do_imaging => do_imaging,
        imaging_done => imaging_done,

        status => status,
        
        frame_request => frame_request_mainclock,
        exposure_start => exposure_start_mainclock
    );

    -- Translate frame_request to sensor clock domain
    frame_request_clock_bridge : clock_bridge port map (
        reset_n => reset_n,
        i_clock => clock,
        i => frame_request_mainclock,
        o_clock => sensor_clock,
        o => frame_request
    );

     -- Translate do_imaging to sensor clock domain
     exposure_start_clock_bridge : clock_bridge port map (
        reset_n => reset_n,
        i_clock => clock,
        i => exposure_start_mainclock,
        o_clock => sensor_clock,
        o => exposure_start
    );

end architecture rtl;
