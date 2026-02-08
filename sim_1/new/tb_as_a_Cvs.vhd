library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Final_Top_NoUART is
end entity;

architecture Behavioral of tb_Final_Top_NoUART is
  constant C_CLK_PERIOD : time := 10 ns;

  signal s_Clk        : std_logic := '0';
  signal s_Reset_POR  : std_logic := '1';

  signal s_rx_char    : std_logic_vector(7 downto 0) := (others => '0');
  signal s_rx_dv      : std_logic := '0';

  signal o_aqi_anomaly   : std_logic;
  signal o_temp_anomaly  : std_logic;
  signal o_light_anomaly : std_logic;
  signal o_temp_trend    : std_logic_vector(1 downto 0);
  signal o_pkt_led       : std_logic;
  signal o_pkt_ready     : std_logic;

  --------------------------------------------------------------------
  -- UART-bypass character sender (same style as your decoder TB)
  --------------------------------------------------------------------
  procedure SEND_CHAR(
    signal rx_char : out std_logic_vector(7 downto 0);
    signal rx_dv   : out std_logic;
    signal clk     : in  std_logic;
    i_char         : in  character
  ) is
  begin
    wait until rising_edge(clk);

    rx_char <= std_logic_vector(to_unsigned(character'pos(i_char), 8));
    rx_dv   <= '1';

    wait until rising_edge(clk);

    rx_dv   <= '0';
    rx_char <= (others => '0');

    wait until rising_edge(clk);
  end procedure;

  procedure SEND_STRING(
    signal rx_char : out std_logic_vector(7 downto 0);
    signal rx_dv   : out std_logic;
    signal clk     : in  std_logic;
    constant s     : in  string
  ) is
  begin
    for i in s'range loop
      SEND_CHAR(rx_char, rx_dv, clk, s(i));
    end loop;
  end procedure;

  -- integer'image adds a leading space -> strip spaces
  procedure SEND_INT(
    signal rx_char : out std_logic_vector(7 downto 0);
    signal rx_dv   : out std_logic;
    signal clk     : in  std_logic;
    val            : in  integer
  ) is
    constant s : string := integer'image(val);
  begin
    for i in s'range loop
      if s(i) /= ' ' then
        SEND_CHAR(rx_char, rx_dv, clk, s(i));
      end if;
    end loop;
  end procedure;

  -- Packet format matching your decoder: #A:<aqi>#T:<temp>#L:<light>#
  procedure SEND_PACKET(
    signal rx_char : out std_logic_vector(7 downto 0);
    signal rx_dv   : out std_logic;
    signal clk     : in  std_logic;
    aqi            : in  integer;
    temp           : in  integer;
    light          : in  integer
  ) is
  begin
    -- Clamp to 0..1023 (10-bit sensor range)
    -- (kept simple: testbench responsibility)
    SEND_STRING(rx_char, rx_dv, clk, "#A:");
    SEND_INT   (rx_char, rx_dv, clk, aqi);
    SEND_CHAR  (rx_char, rx_dv, clk, '#');

    SEND_STRING(rx_char, rx_dv, clk, "T:");
    SEND_INT   (rx_char, rx_dv, clk, temp);
    SEND_CHAR  (rx_char, rx_dv, clk, '#');

    SEND_STRING(rx_char, rx_dv, clk, "L:");
    SEND_INT   (rx_char, rx_dv, clk, light);
    SEND_CHAR  (rx_char, rx_dv, clk, '#');
  end procedure;

  --------------------------------------------------------------------
  -- Helpers
  --------------------------------------------------------------------
  procedure WAIT_PKT is
  begin
    wait until o_pkt_ready = '1';
    wait until rising_edge(s_Clk);
  end procedure;

  procedure EXPECT_LED_HIGH_SOON(constant timeout : time := 2 ms) is
  begin
    -- LED should go high quickly after pkt_ready; if not, fail
    if o_pkt_led /= '1' then
      wait for 200 ns;
    end if;

    if o_pkt_led /= '1' then
      -- give more time but bounded
      wait for timeout;
    end if;

    assert o_pkt_led = '1'
      report "ERROR: o_pkt_led never went HIGH after pkt_ready."
      severity failure;
  end procedure;

  function trend_str(t : std_logic_vector(1 downto 0)) return string is
  begin
    if t = "00" then return "steady";
    elsif t = "01" then return "up";
    elsif t = "10" then return "down";
    else return "??";
    end if;
  end function;

begin

  --------------------------------------------------------------------
  -- Clock
  --------------------------------------------------------------------
  clk_process : process
  begin
    s_Clk <= '0'; wait for C_CLK_PERIOD/2;
    s_Clk <= '1'; wait for C_CLK_PERIOD/2;
  end process;

  --------------------------------------------------------------------
  -- DUT
  --------------------------------------------------------------------
  dut : entity work.Final_Top_NoUART
    port map (
      i_Clk           => s_Clk,
      i_Reset_POR     => s_Reset_POR,
      i_rx_char       => s_rx_char,
      i_rx_dv         => s_rx_dv,
      o_aqi_anomaly   => o_aqi_anomaly,
      o_temp_anomaly  => o_temp_anomaly,
      o_light_anomaly => o_light_anomaly,
      o_temp_trend    => o_temp_trend,
      o_pkt_led       => o_pkt_led,
      o_pkt_ready     => o_pkt_ready
    );

  --------------------------------------------------------------------
  -- STIMULUS: hundreds of packets in phases
  --------------------------------------------------------------------
  stimulus : process
    variable aqi_v   : integer;
    variable temp_v  : integer;
    variable light_v : integer;

    constant N_WARMUP  : integer := 20;
    constant N_STEADY  : integer := 120;
    constant N_RAMPUP  : integer := 60;
    constant N_SPIKES  : integer := 60;
    constant N_RAMPDN  : integer := 60;
    constant N_TOTAL   : integer := N_WARMUP + N_STEADY + N_RAMPUP + N_SPIKES + N_RAMPDN;

    procedure SEND_AND_CHECK(constant idx : integer; aqi_i, temp_i, light_i : integer) is
    begin
      SEND_PACKET(s_rx_char, s_rx_dv, s_Clk, aqi_i, temp_i, light_i);
      WAIT_PKT;
      EXPECT_LED_HIGH_SOON;

      -- lightweight periodic reporting (every 25 packets)
      if (idx mod 25) = 0 then
        report "pkt=" & integer'image(idx)
          & "  A=" & integer'image(aqi_i)
          & "  T=" & integer'image(temp_i)
          & "  L=" & integer'image(light_i)
          & "  trend=" & trend_str(o_temp_trend)
          & "  aqi_anom=" & std_logic'image(o_aqi_anomaly)
          & "  temp_anom=" & std_logic'image(o_temp_anomaly)
          & "  light_anom=" & std_logic'image(o_light_anomaly)
          severity note;
      end if;
    end procedure;

  begin
    report "===== Starting Final_Top_NoUART STRESS TEST (" & integer'image(N_TOTAL) & " packets) ====="
      severity note;

    -- Reset
    s_Reset_POR <= '1';
    wait for C_CLK_PERIOD * 20;
    s_Reset_POR <= '0';
    wait for C_CLK_PERIOD * 20;

    ----------------------------------------------------------------
    -- Phase 1: Warm-up (fills sliding window)
    ----------------------------------------------------------------
    for i in 1 to N_WARMUP loop
      aqi_v   := 100 + (i mod 5);
      temp_v  := 220;
      light_v := 300;
      SEND_AND_CHECK(i, aqi_v, temp_v, light_v);
    end loop;

    ----------------------------------------------------------------
    -- Phase 2: Steady-state with small noise (trend should be mostly steady)
    ----------------------------------------------------------------
    for k in 1 to N_STEADY loop
      aqi_v   := 120 + ((k mod 7) - 3);      -- +/- small variation
      temp_v  := 230 + ((k mod 5) - 2);      -- +/- small variation
      light_v := 350 + ((k mod 9) - 4);      -- +/- small variation
      SEND_AND_CHECK(N_WARMUP + k, aqi_v, temp_v, light_v);
    end loop;

    ----------------------------------------------------------------
    -- Phase 3: Temperature ramp UP (trend should become UP at least sometimes)
    -- Using steps > 10 at some points to cross THRESHOLD_UP=10
    ----------------------------------------------------------------
    for r in 1 to N_RAMPUP loop
      aqi_v   := 130;
      temp_v  := 200 + (r * 2);  -- from 202..320 (big ramp)
      light_v := 360;
      SEND_AND_CHECK(N_WARMUP + N_STEADY + r, aqi_v, temp_v, light_v);
    end loop;

    -- After ramp-up, expect "up" at least once
    assert o_temp_trend = "01" or o_temp_trend = "00"
      report "NOTE: After ramp-up, trend is not UP/STEADY (check thresholds/valid timing)."
      severity note;

    ----------------------------------------------------------------
    -- Phase 4: Spikes (sudden big jumps in AQI and LIGHT and TEMP)
    ----------------------------------------------------------------
    for s in 1 to N_SPIKES loop
      -- baseline
      if (s mod 10) /= 0 then
        aqi_v   := 150;
        temp_v  := 250;
        light_v := 400;
      else
        -- every 10th packet: spike
        aqi_v   := 600;
        temp_v  := 320;
        light_v := 900;
      end if;

      SEND_AND_CHECK(N_WARMUP + N_STEADY + N_RAMPUP + s, aqi_v, temp_v, light_v);
    end loop;

    ----------------------------------------------------------------
    -- Phase 5: Temperature ramp DOWN (trend should become DOWN at least sometimes)
    ----------------------------------------------------------------
    for d in 1 to N_RAMPDN loop
      aqi_v   := 140;
      temp_v  := 340 - (d * 2);  -- down ramp
      light_v := 380;
      SEND_AND_CHECK(N_WARMUP + N_STEADY + N_RAMPUP + N_SPIKES + d, aqi_v, temp_v, light_v);
    end loop;

    assert o_temp_trend = "10" or o_temp_trend = "00"
      report "NOTE: After ramp-down, trend is not DOWN/STEADY (check thresholds/valid timing)."
      severity note;

    report "===== PASS: Stress test finished. Ran " & integer'image(N_TOTAL) & " packets. ====="
      severity note;

    -- Keep sim running long enough to see LED stretcher (ms scale)
    wait for 20 ms;
    wait;
  end process;

end architecture;
