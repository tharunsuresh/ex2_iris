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
use ieee.math_real.all;

use work.integer_types.all;

use work.vnir_base.all;
use work.pixel_integrator_pkg.all;

-- Collects pixels from the sensor, stores and sums (or averages) the
-- overlapping pixels, then outputs the sum (or average).
--
-- `pixel_integrator` is configured with two values:
-- * `windows`: an array of windows, with `windows(0)` corresponding to
--   the leading window, and `windows(N_WINDOWS-1)` corresponding to the
--   lagging window. These must match the windows used to configure the
--   sensor.
-- * `image_length`: the number of rows the output image will have. Note
--   that this is different than the number of input frames
--   `pixel_integrator` expects to recieve from the sensor, because
--   `pixel_integrator` needs to recieve some extra frames at the beginning
--   and end of imaging so as to be able to maintain the same number of
--   passes over the pixels near the edges of the image. In particular,
--   the required number of input frames is:
--
--       image_frames = image_length + windows(N_WINDOWS-1).hi
--
-- To configure `pixel_integrator`, set it's `config` input to the desired
-- values and assert `read_config` for a single clock cycle.
--
-- Once configured, assert `start` for a single clock cycle.
--
-- Then, the image frames are to be input row by row, with rows input
-- fragment by fragment, through the `fragment` and `fragment_available`
-- inputs. `pixel_integrator` will hold `done` high for a single clock
-- cycle when it has recieved all the rows it expects (note, because of
-- internal pipelining, that this will be delayed by a few clock cycles).
--
-- The fragments are be indexed according to their location on the
-- ground, then fragments with the same index (same location) are summed
-- together. A group of RAM IPs is used to store the intermediate sums.
-- When all the fragments with the same index (same location) have been
-- recieved by the `pixel_integrator`, they are collected into rows and
-- emitted out the `row` output.
--
-- `pixel_integrator` is able to figure out which fragments correspond to
-- the same locations on the ground by assuming the satallite ground
-- speed and the sensor's imaging speed satisfy:
--
--        ground_speed = fps * gsd
--
-- where ground_speed is the speed at which the sensor's imaging surface
-- sweeps the ground, fps is the frames-per-second of the sensor, and
-- gsd is the ground sample distance (the distance between pixel centers
-- on the ground). It is the job of components external to
-- `pixel_integrator` to ensure fps is set such that this relation holds.
entity pixel_integrator is
generic (
    ROW_WIDTH           : integer;
    FRAGMENT_WIDTH      : integer;
    PIXEL_BITS          : integer;
    ROW_PIXEL_BITS      : integer;
    N_WINDOWS           : integer range 1 to MAX_N_WINDOWS;
    METHOD              : string;
    MAX_WINDOW_SIZE     : integer
);
port (
    clock               : in std_logic;
    reset_n             : in std_logic;

    config              : in config_t;
    read_config         : in std_logic;

    start               : in std_logic;
    done                : out std_logic;

    fragment            : in pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
    fragment_available  : in std_logic;

    row                 : out pixel_vector_t(ROW_WIDTH-1 downto 0)(ROW_PIXEL_BITS-1 downto 0);
    row_window          : out integer;

    status              : out status_t
);
end entity pixel_integrator;


architecture rtl of pixel_integrator is

    component pixel_integrator_fifo is
    generic (
        WORD_SIZE       : integer;
        ADDRESS_SIZE    : integer
    );
    port (
        clock           : in std_logic;
        read_data       : out std_logic_vector;
        read_address    : in std_logic_vector;
        read_enable     : in std_logic;
        write_data      : in std_logic_vector;
        write_address   : in std_logic_vector;
        write_enable    : in std_logic
    );
    end component pixel_integrator_fifo;

    constant FRAGMENTS_PER_ROW : integer := ROW_WIDTH / FRAGMENT_WIDTH;
    -- Number of bits needed to ensure pixel summing doesn't overflow.
    -- In the worst case, we sum together n m-bit pixels, with
    -- n=MAX_WINDOW_SIZE and m=PIXEL_BITS
    constant SUM_BITS : integer := integer(ceil(log2(real(2) ** real(PIXEL_BITS) * real(MAX_WINDOW_SIZE))));
    -- Number of bits needed to ensure all intermediate sums may be
    -- stored in RAM
    constant ADDRESS_BITS : integer := integer(ceil(log2(real(ROW_WIDTH / FRAGMENT_WIDTH) * real(N_WINDOWS) * real(MAX_WINDOW_SIZE))));

    -- Gets the address in RAM of a particular fragment, according to
    --
    --        addr = 128 * (n * i_window + x % n) + i_fragment
    --
    -- where n is the maximum window size, and x, i_window and i_fragment
    -- is the index of the fragment
    pure function to_address(index : fragment_idx_t; windows : window_vector_t) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(
            FRAGMENTS_PER_ROW * (
                index.i_window * max_n(sizes(windows)) +
                index.x rem max_n(sizes(windows))
            ) + index.i_fragment,
            ADDRESS_BITS
        ));
    end function to_address;

    -- Pipeline stage 0 output
    signal fragment_p0  : pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
    signal index_p0     : fragment_idx_t;
    signal p0_done      : std_logic;
    -- Pipeline stage 1 output
    signal fragment_p1  : pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
    signal index_p1     : fragment_idx_t;
    signal p1_done      : std_logic;
    -- Pipeline stage 2 output
    signal fragment_p2  : pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
    signal index_p2     : fragment_idx_t;
    signal p2_done      : std_logic;
    -- Pipeline stage 3 output
    signal fragment_p3  : pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(ROW_PIXEL_BITS-1 downto 0);
    signal index_p3     : fragment_idx_t;
    signal p3_done      : std_logic;

    -- RAM signals
    signal read_data        : lpixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(SUM_BITS-1 downto 0);
    signal read_address     : std_logic_vector(ADDRESS_BITS-1 downto 0);
    signal read_enable      : std_logic;
    signal write_data       : lpixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(SUM_BITS-1 downto 0);
    signal write_address    : std_logic_vector(ADDRESS_BITS-1 downto 0);
    signal write_enable     : std_logic;

    -- Config registers
    signal windows : window_vector_t(N_WINDOWS-1 downto 0);
    signal length : integer;

begin

    config_process : process (clock, reset_n)
    begin
        if reset_n = '0' then
            windows <= (others => (others => 0));
            length <= 0;
        elsif rising_edge(clock) then
            if read_config = '1' then
                for i in 0 to N_WINDOWS-2 loop
                    assert 0 <= config.windows(i).lo;
                    assert config.windows(i).lo <= config.windows(i).hi;
                    assert config.windows(i).hi < config.windows(i+1).hi;
                    assert config.windows(i+1).hi < 2048;
                end loop;
                
                windows <= config.windows(N_WINDOWS-1 downto 0);
                length <= config.length;
            end if;
        end if;
    end process config_process;

    -- Pipeline stage 0: tag fragment with index
    -- TODO: should probably be its own entity
    p0 : process (clock, reset_n)
        variable i_fragment : integer;
        variable i_row      : integer;
        variable i_window   : integer;
        variable i_frame    : integer;
        variable rollover   : boolean;
        variable x          : integer;
    begin
        if reset_n = '0' then
            p0_done <= '0';
        elsif rising_edge(clock) then
            p0_done <= '0';
            status.fragment_available <= fragment_available;
            if start = '1' then
                i_fragment := 0;
                i_row := 0;
                i_window := 0;
                i_frame := 0;
            elsif fragment_available = '1' then
                x := i_frame - windows(i_window).lo - i_row;
                status.fragment_x <= x;
                fragment_p0 <= fragment;
                index_p0 <= (
                    x => x,
                    i_fragment => i_fragment,
                    i_window => i_window,
                    is_leading => i_row = 0,
                    is_lagging => i_row = size(windows(i_window))-1
                );
                increment_rollover(i_fragment, FRAGMENTS_PER_ROW, true, rollover);
                increment_rollover(i_row, size(windows(i_window)), rollover, rollover);
                increment_rollover(i_window, N_WINDOWS, rollover, rollover);
                increment(i_frame, rollover);
                p0_done <= '1';
            end if;
        end if;
    end process p0;

    -- Pipeline stage 1: Filter out-of-bounds fragments, request stored sum values of
    -- previous fragments overlapping with the input fragment
    p1 : process (clock, reset_n)
    begin
        if reset_n = '0' then
            p1_done <= '0';
            read_enable <= '0';
            read_address <= (others => '0');
        elsif rising_edge(clock) then
            p1_done <= '0';
            read_enable <= '0';
            if p0_done = '1' then
                if 0 <= index_p0.x and index_p0.x < length then
                    -- Make previous sum available for next pipeline stage
                    if not index_p0.is_leading then
                        read_address <= to_address(index_p0, windows);
                        read_enable <= '1';
                    end if;
                    -- Advance to next pipeline stage
                    fragment_p1 <= fragment_p0;
                    index_p1 <= index_p0;
                    p1_done <= '1';
                end if;
            end if;
        end if;
    end process p1;

    -- Pipeline stage 2: delay until the sum is ready
    p2 : process (clock, reset_n)
    begin
        if reset_n = '0' then
            p2_done <= '0';
        elsif rising_edge(clock) then
            p2_done <= p1_done;
            if p1_done = '1' then
                fragment_p2 <= fragment_p1;
                index_p2 <= index_p1;
            end if;
        end if;
    end process p2;

    -- Pipeline stage 3: read in the sum requested in pipeline stage 1, and update it
    -- by adding this fragment to it. Write the result back into RAM. Possibly compute the
    -- average from the sum and export it to the next pipeline stage.
    p3 : process (clock, reset_n)
        variable sum : pixel_vector_t(fragment_p1'range)(SUM_BITS-1 downto 0);
    begin
        if reset_n = '0' then
            p3_done <= '0';
            write_enable <= '0';
            write_address <= (others => '0');
        elsif rising_edge(clock) then
            p3_done <= '0';
            write_enable <= '0';
            if p2_done = '1' then
                -- Add to running sum
                if index_p2.is_leading then
                    sum := resize_pixels(fragment_p2, SUM_BITS);
                else
                    sum := resize_pixels(fragment_p2, SUM_BITS) + to_pixels(read_data);
                end if;

                -- Write new running sum to RAM
                write_address <= to_address(index_p2, windows);
                write_data <= to_lpixels(sum);
                write_enable <= '1';

                -- If this fragment is on the lagging edge of a window, we have done all the
                -- passes we can on the fragments with its index, so emit the summed/averaged
                -- fragment.
                if index_p2.is_lagging then
                    if METHOD = "SUM" then
                        fragment_p3 <= resize_pixels(sum, ROW_PIXEL_BITS);
                    elsif METHOD = "AVERAGE" then
                        fragment_p3 <= resize_pixels(
                            shift_divide(sum, to_unsigned(size(windows(index_p2.i_window)), 11)),
                            ROW_PIXEL_BITS
                        );
                    else
                        report "Unrecognized METHOD" severity failure;
                    end if;
                    index_p3 <= index_p2;
                    p3_done <= '1';
                end if;
            end if;
        end if;
    end process p3;

    -- Pipeline stage 4: collect the summed/averaged fragments from the previous pipeline stage
    -- into rows.
    p4 : process (clock, reset_n)
        variable i_frame : integer;
    begin
        if reset_n = '0' then
            row_window <= -1;
            done <= '0';
        elsif rising_edge(clock) then
            row_window <= -1;
            done <= '0';

            if start = '1' then
                i_frame := 0;
            elsif p3_done = '1' then
                -- Insert fragment into row
                for i in fragment_p3'range loop
                    row(index_p3.i_fragment + i * FRAGMENTS_PER_ROW) <= fragment_p3(i);
                end loop;
                -- If this is the last fragment of the row, emit the row
                if index_p3.i_fragment = FRAGMENTS_PER_ROW-1 then
                    -- Emit row
                    row_window <= index_p3.i_window;
                    -- If this is the last window, we have finished processing a frame
                    if index_p3.i_window = N_WINDOWS-1 then
                        -- If this is the last frame, we are done
                        if i_frame = length-1 then
                            done <= '1';
                        end if;
                        i_frame := i_frame + 1;
                    end if;
                end if;
            end if;
        end if;
    end process p4;

    -- Use multiple RAMs in parallel, so that reading or writing a fragment
    -- takes a single clock cycle
    generate_RAM : for i in 0 to FRAGMENT_WIDTH-1 generate

        RAM : pixel_integrator_fifo generic map (
            WORD_SIZE => SUM_BITS,
            ADDRESS_SIZE => ADDRESS_BITS
        ) port map (
            clock => clock,
            read_data => read_data(i),
            read_address => read_address,
            read_enable => read_enable,
            write_data => write_data(i),
            write_address => write_address,
            write_enable => write_enable
        );

    end generate;

end architecture rtl;
