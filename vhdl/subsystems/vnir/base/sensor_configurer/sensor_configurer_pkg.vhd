library ieee;
use ieee.numeric_std.all;

package sensor_configurer_defaults is
    
    constant POWER_ON_DELAY_us   : integer := 1;
    constant CLOCK_ON_DELAY_us   : integer := 1;
    constant RESET_OFF_DELAY_us  : integer := 1;
    constant SPI_SETTLE_us       : integer := 20000;

end package sensor_configurer_defaults;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.logic_types.all;
use work.vnir_base.all;

package sensor_configurer_pkg is

    -- Maximum number of windows `sensor_configurer` can be configured
    -- to use
    constant MAX_N_WINDOWS : integer := 10;

    -- Whether to flip the image when reading it out
    type flip_t is (FLIP_NONE, FLIP_X, FLIP_Y, FLIP_XY);

    -- Configuration values to be uploaded to the sensor in instruction
    -- form.
    type config_t is record
        flip        : flip_t;
        calibration : calibration_t;
        windows     : window_vector_t(MAX_N_WINDOWS-1 downto 0);
    end record config_t;

    -- Possible states of `sensor_configurer`. Defined in a globally-
    -- accessible scope so that the state may be included in the status
    -- register
    type state_t is (OFF, IDLE, CONFIG_POWER_ON, CONFIG_CLOCK_ON, CONFIG_RESET_OFF,
                     CONFIG_TRANSMIT, CONFIG_TRANSMIT_FINISH, CONFIG_SPI_SETTLE);

    -- `sensor_configurer` status register, to be used for debugging
    type status_t is record
        state   : state_t;
    end record status_t;


    -- The following functions build the sensor's configuration data
    -- from human-readable configuration parameters. Check the user
    -- manual for more information.

    -- Generates the instructions required to set an 8-bit value at a
    -- given address
    pure function l8_instructions(l8 : logic8_t; addr : integer) return logic16_vector_t;
    pure function i8_instructions(i8 : integer; addr : integer) return logic16_vector_t;
    -- Generates the instructions required to set a 16-bit value at a
    -- given address
    pure function l16_instructions(l16 : logic16_t; addr : integer) return logic16_vector_t;
    pure function i16_instructions(i16 : integer; addr : integer) return logic16_vector_t;
    
    -- Generates the instructions required to configure a single window
    pure function window_instructions(window : window_t; index : integer) return logic16_vector_t;
    -- Generates the instructions to configure all the windows in `config`
    pure function window_instructions(config : config_t; N_WINDOWS : integer) return logic16_vector_t;
    -- Generates the instructions to configure image flipping
    pure function flip_instructions(flip : flip_t) return logic16_vector_t;
    -- Generates instructions to to set or unset miscellaneous flags,
    -- given to `misc_instructions` as a bitwise argument. Possible
    -- flags are:
    -- * EXTERNAL_EXPOSURE : enable external-exposure mode
    -- * DUAL_EXPOSURE     : enable dual-exposure mode
    -- * DUMMY_INSERTION   : enable dummy-data insertion when no data
    --                       is available 
    pure function misc_instructions(flags : std_logic_vector) return logic16_vector_t;
    -- Generates instructions to set the number of output channels the
    -- sensor will use
    pure function n_channels_instructions(n_channels : integer) return logic16_vector_t;
    -- Generates instructions to set the sensor's calibration values
    pure function calibration_instructions(calibration : calibration_t) return logic16_vector_t;
    -- Generates instructions to set the sensor's bit-mode, i.e. whether
    -- to use 10-bit or 12-bit pixels
    pure function bit_mode_instructions(pixel_bits : integer) return logic16_vector_t;
    -- Generate instructions to configure the sensor's internal PLL
    -- according to the expected sensor clock frequency
    pure function pll_instructions(sensor_clock_MHz : integer; pixel_bits : integer) return logic16_vector_t;
    -- Generate instructions that are required according to the manual,
    -- but who's functions are otherwise undocumented
    pure function undocumented_instructions return logic16_vector_t;
    
    -- Generates all configuration instructions, setting the sensor
    -- to external-exposure mode, it's expected clock frequency to
    -- 48MHz, and various other values to the settings consistent with
    -- the input parameters
    pure function all_instructions (config : config_t;  FRAGMENT_WIDTH : integer;
                                    PIXEL_BITS : integer; N_WINDOWS : integer
                                   ) return logic16_vector_t;

end package sensor_configurer_pkg;


package body sensor_configurer_pkg is

    pure function l8_instructions(l8 : logic8_t; addr : integer) return logic16_vector_t is
        variable instructions : logic16_vector_t(0 downto 0);
    begin
        -- Setting a single byte in the sensor's internal register can
        -- be done using a single 16-bit instruction
        instructions(0) := '1' & to_logic7(addr) & l8;
        return instructions;
    end function l8_instructions;

    pure function i8_instructions(i8 : integer; addr : integer) return logic16_vector_t is
    begin
        return l8_instructions(to_logic8(i8), addr);
    end function i8_instructions;

    pure function l16_instructions(l16 : logic16_t; addr : integer) return logic16_vector_t is
        variable instructions : logic16_vector_t(2-1 downto 0);
    begin
        -- Setting two bytes in the sensor's internal register is done
        -- with two 16-bit instructions
        instructions(1) := '1' & to_logic7(addr + 0) & l16(7 downto 0);
        instructions(0) := '1' & to_logic7(addr + 1) & l16(15 downto 8);
        return instructions;
    end function l16_instructions;

    pure function i16_instructions(i16 : integer; addr : integer) return logic16_vector_t is
    begin
        return l16_instructions(to_logic16(i16), addr);
    end function i16_instructions;

    pure function window_instructions(window : window_t; index : integer) return logic16_vector_t is
        constant ADDR_LOW_BASE : integer := 3;
        constant ADDR_SIZE_BASE : integer := 19;
        constant ADDR_STRIDE : integer := 2;
    begin
        return i16_instructions(window.lo, ADDR_LOW_BASE + ADDR_STRIDE * index)
             & i16_instructions(size(window), ADDR_SIZE_BASE + ADDR_STRIDE * index);
    end function window_instructions;

    pure function window_instructions(config : config_t; N_WINDOWS : integer) return logic16_vector_t is
        constant ADDR_TOTAL_ROWS : integer := 1;
        variable w : logic16_vector_t(4 + 4 * N_WINDOWS - 1 downto 0);
    begin
        assert N_WINDOWS <= MAX_N_WINDOWS;
        w(w'high downto w'high-1) :=i16_instructions(total_rows(config.windows), ADDR_TOTAL_ROWS);
        for i in 0 to N_WINDOWS-1 loop
            w(4*i+3 downto 4*i) := window_instructions(config.windows(i), i);
        end loop;
        return w;
    end function window_instructions;

    pure function flip_instructions(flip : flip_t) return logic16_vector_t is
        constant ADDR_FLIP : integer := 40;
    begin
        case flip is
        when FLIP_NONE => return i8_instructions(0, ADDR_FLIP);
        when FLIP_X => return i8_instructions(1, ADDR_FLIP);
        when FLIP_Y => return i8_instructions(2, ADDR_FLIP);
        when FLIP_XY => return i8_instructions(3, ADDR_FLIP);
        end case;
    end function flip_instructions;

    constant EXTERNAL_EXPOSURE : std_logic_vector(3-1 downto 0) := "001";
    constant DUAL_EXPOSURE     : std_logic_vector(3-1 downto 0) := "010";
    constant DUMMY_INSERTION   : std_logic_vector(3-1 downto 0) := "100";

    pure function to_std_logic(b : boolean) return std_logic is
    begin
        if b then return '1'; else return '0'; end if;
    end function to_std_logic;

    pure function misc_instructions(flags : std_logic_vector) return logic16_vector_t is
        constant ADDR_MISC : integer := 41;
        variable dummy_insertion_bit : std_logic;
        variable dual_exposure_bit : std_logic;
        variable external_exposure_bit : std_logic;
        variable encoded_flags : logic8_t;
    begin
        dummy_insertion_bit   := to_std_logic(bitwise_contains(flags, DUMMY_INSERTION));
        dual_exposure_bit     := to_std_logic(bitwise_contains(flags, DUAL_EXPOSURE));
        external_exposure_bit := to_std_logic(bitwise_contains(flags, EXTERNAL_EXPOSURE));

        encoded_flags := "00000" & dummy_insertion_bit & dual_exposure_bit & external_exposure_bit;
        return l8_instructions(encoded_flags, ADDR_MISC);
    end function misc_instructions;

    pure function n_channels_instructions(n_channels : integer) return logic16_vector_t is
        -- For now this function leaves all channels enabled
        constant ADDR_N_CHANNELS : integer := 72;
    begin
        case n_channels is
        when 16 => return i8_instructions(0, ADDR_N_CHANNELS);
        when  8 => return i8_instructions(1, ADDR_N_CHANNELS);
        when  4 => return i8_instructions(2, ADDR_N_CHANNELS);
        when  2 => return i8_instructions(3, ADDR_N_CHANNELS);
        when others =>
            report "Invalid number of channels detected in n_channels_instructions()" severity failure;
            return i8_instructions(0, ADDR_N_CHANNELS);
        end case;
    end function n_channels_instructions;

    pure function calibration_instructions(calibration : calibration_t) return logic16_vector_t is
        constant ADDR_ADC_GAIN : integer := 103;
        constant ADDR_V_RAMP1 : integer := 98;
        constant ADDR_V_RAMP2 : integer := 99;
        constant ADDR_OFFSET : integer := 100;
    begin
        return i8_instructions(calibration.adc_gain, ADDR_ADC_GAIN)
             & i8_instructions(calibration.v_ramp1, ADDR_V_RAMP1)
             & i8_instructions(calibration.v_ramp2, ADDR_V_RAMP2)
             & i16_instructions(calibration.offset, ADDR_OFFSET);
    end;

    pure function bit_mode_instructions(pixel_bits : integer) return logic16_vector_t is
        constant ADDR_BIT_MODE : integer := 111;
        constant ADDR_ADC_RES : integer := 112;
        variable bit_mode : integer;
        variable adc_res : integer;
    begin
        if pixel_bits /= 10 and pixel_bits /= 12 then
            report "Invalid bit mode detected in bit_mode_instructions()" severity failure;
        end if;

        if pixel_bits = 10 then bit_mode := 1; else bit_mode := 0; end if;
        if pixel_bits = 10 then adc_res := 0; else adc_res := 2; end if;

        return i8_instructions(bit_mode, ADDR_BIT_MODE)
                & i8_instructions(adc_res, ADDR_ADC_RES);
    end function bit_mode_instructions;

    pure function pll_instructions(sensor_clock_MHz : integer; pixel_bits : integer) return logic16_vector_t is
        constant ADDR_PLL_RANGE : integer := 116;
        constant ADDR_PLL_LOAD : integer := 117;
        constant ADDR_PLL_IN_FREQ : integer := 114;
        variable pll_load : integer;
        variable pll_div : integer;
        variable pll_range : integer;
        variable pll_out_freq : integer;
        variable pll_in_freq : integer;
    begin
        if pixel_bits /= 10 and pixel_bits /= 12 then
            report "Invalid bit mode detected in pll_instructions()" severity failure;
        end if;

        if pixel_bits = 10 then pll_load := 8; else pll_load := 4; end if;
        if pixel_bits = 10 then pll_div := 9; else pll_div := 11; end if;
        
        case sensor_clock_MHz is
        when 48 downto 31 => pll_range := 1; pll_out_freq := 5; pll_in_freq := 0;
        when 30 downto 21 => pll_range := 0; pll_out_freq := 1; pll_in_freq := 0;
        when 20 downto 16 => pll_range := 1; pll_out_freq := 1; pll_in_freq := 1;
        when 15 downto 11 => pll_range := 0; pll_out_freq := 2; pll_in_freq := 1;
        when 10 downto  8 => pll_range := 1; pll_out_freq := 2; pll_in_freq := 3;
        when  7 downto  5 => pll_range := 0; pll_out_freq := 0; pll_in_freq := 3;
        when others =>
            report "Invalid sensor clock speed in pll_instructions()" severity failure;
            pll_range := 1; pll_out_freq := 5; pll_in_freq := 0;
        end case;

        return l8_instructions(to_logic1(pll_range) & to_logic3(pll_out_freq) & to_logic4(pll_div), ADDR_PLL_RANGE)
                & i8_instructions(pll_load, ADDR_PLL_LOAD)
                & i8_instructions(pll_in_freq, ADDR_PLL_IN_FREQ);
    end function pll_instructions;

    pure function undocumented_instructions return logic16_vector_t is
        -- There are a lot of instructions specified on page 43 of the manual that have recommended
        -- initial values, but are otherwise undocumented. They are initialized here.
    begin
        return i8_instructions(0, 77)
             & i8_instructions(4, 84)
             & i8_instructions(1, 85)
             & i8_instructions(14, 86)
             & i8_instructions(12, 87)
             & i8_instructions(64, 88)
             & i8_instructions(64, 91)
             & i8_instructions(101, 94)
             & i8_instructions(106, 95)
             & i8_instructions(1, 102)
             & i8_instructions(1, 118)
             & i8_instructions(98, 123);
    end function undocumented_instructions;

    pure function all_instructions (config : config_t; FRAGMENT_WIDTH : integer; PIXEL_BITS : integer; N_WINDOWS : integer) return logic16_vector_t is
        -- TODO: check out i_lvds
    begin
        return window_instructions(config, N_WINDOWS)
             & flip_instructions(config.flip)
             & misc_instructions(EXTERNAL_EXPOSURE or DUMMY_INSERTION)
             & n_channels_instructions(FRAGMENT_WIDTH)
             & calibration_instructions(config.calibration)
             & bit_mode_instructions(PIXEL_BITS)
             & pll_instructions(48, PIXEL_BITS)  -- TODO: set this properly
             & undocumented_instructions;
    end function all_instructions;

end package body sensor_configurer_pkg;
