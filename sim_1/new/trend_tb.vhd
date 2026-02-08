library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Trend_Detector_TB is
end Trend_Detector_TB;

architecture TB of Trend_Detector_TB is

    -- Component under test
    component Trend_Detector is
      generic (
        DATA_WIDTH      : integer := 10;
        THRESHOLD_UP    : integer := 10;
        THRESHOLD_DOWN  : integer := 10
      );
      port (
        i_Clk           : in  std_logic;
        i_Reset         : in  std_logic;
        i_filtered_val  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_valid         : in  std_logic;
        o_trend         : out std_logic_vector(1 downto 0);
        o_spike_alert   : out std_logic
      );
    end component;

    ----------------------------------------------------------------------
    -- Signals
    ----------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    signal s_clk         : std_logic := '0';
    signal s_reset       : std_logic := '1';

    signal s_val         : std_logic_vector(9 downto 0) := (others => '0');
    signal s_valid       : std_logic := '0';

    signal s_trend       : std_logic_vector(1 downto 0);
    signal s_spike       : std_logic;

    -- Test vector sequence (filtered AQI values)
    type t_array is array(0 to 7) of integer;
    constant TEST_VALUES : t_array :=
      (100, 110, 150, 155, 90, 85, 300, 310);

begin

    ----------------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------------
    s_clk <= not s_clk after CLK_PERIOD/2;


    ----------------------------------------------------------------------
    -- Instantiate DUT
    ----------------------------------------------------------------------
    DUT : Trend_Detector
      generic map (
        DATA_WIDTH      => 10,
        THRESHOLD_UP    => 10,
        THRESHOLD_DOWN  => 10
      )
      port map (
        i_Clk           => s_clk,
        i_Reset         => s_reset,
        i_filtered_val  => s_val,
        i_valid         => s_valid,
        o_trend         => s_trend,
        o_spike_alert   => s_spike
      );


    ----------------------------------------------------------------------
    -- Stimulus process
    ----------------------------------------------------------------------
    stim : process
    begin

        report "===== Starting Trend Detector Testbench =====";

        -- Reset pulse
        s_reset <= '1';
        wait for 50 ns;
        s_reset <= '0';
        wait for 20 ns;

        -- Apply test values one-by-one
        for i in TEST_VALUES'range loop

            s_val <= std_logic_vector(to_unsigned(TEST_VALUES(i), 10));
            s_valid <= '1';
            wait for CLK_PERIOD;
            s_valid <= '0';

            wait for CLK_PERIOD * 3;

            -- Log the results on the console
            report "Input: " & integer'image(TEST_VALUES(i)) &
                   "   Trend code=" & std_logic'image(s_trend(1)) & std_logic'image(s_trend(0)) &
                   "   Spike=" & std_logic'image(s_spike);

        end loop;

        report "===== Trend Detector Test Completed =====";

        wait;
    end process;

end TB;
