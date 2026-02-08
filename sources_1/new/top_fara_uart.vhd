library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Final_Top_NoUART is
  port (
    i_Clk        : in  std_logic;
    i_Reset_POR  : in  std_logic;

    -- bypass UART (drive these from TB)
    i_rx_char    : in  std_logic_vector(7 downto 0);
    i_rx_dv      : in  std_logic;

    -- Status / alerts
    o_aqi_anomaly   : out std_logic;
    o_temp_anomaly  : out std_logic;
    o_light_anomaly : out std_logic;

    o_temp_trend    : out std_logic_vector(1 downto 0);

    -- Debug
    o_pkt_led     : out std_logic;
    o_pkt_ready   : out std_logic
  );
end entity;

architecture RTL of Final_Top_NoUART is

  -- UART-bypass signals
  signal rx_char : std_logic_vector(7 downto 0);
  signal rx_dv   : std_logic;

  -- Decoder outputs
  signal aqi_raw   : std_logic_vector(9 downto 0);
  signal temp_raw  : std_logic_vector(9 downto 0);
  signal light_raw : std_logic_vector(9 downto 0);
  signal pkt_ready : std_logic;

  -- Sliding window block parameters
  constant WINDOW_SIZE_C : integer := 5;

  constant MIN_32 : std_logic_vector(31 downto 0) := (others => '0');
  constant MAX_32 : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(1023, 32));

  -- 32-bit extended inputs
  signal aqi_raw_32   : std_logic_vector(31 downto 0);
  signal temp_raw_32  : std_logic_vector(31 downto 0);
  signal light_raw_32 : std_logic_vector(31 downto 0);

  -- Window SUM outputs
  signal aqi_sum_32   : std_logic_vector(31 downto 0);
  signal temp_sum_32  : std_logic_vector(31 downto 0);
  signal light_sum_32 : std_logic_vector(31 downto 0);

  signal aqi_sum_v   : std_logic;
  signal temp_sum_v  : std_logic;
  signal light_sum_v : std_logic;

  -- Filtered values (10-bit)
  signal aqi_filt   : std_logic_vector(9 downto 0) := (others => '0');
  signal temp_filt  : std_logic_vector(9 downto 0) := (others => '0');
  signal light_filt : std_logic_vector(9 downto 0) := (others => '0');

  -- PID width adaptation
  signal temp_filt_12 : std_logic_vector(11 downto 0);

  -- Trend
  signal temp_trend_i : std_logic_vector(1 downto 0);

  -- Anomalies
  signal aqi_anom   : std_logic;
  signal temp_anom  : std_logic;
  signal light_anom : std_logic;

  -- PID
  signal pid_mv    : std_logic_vector(11 downto 0);
  signal pid_valid : std_logic;

  -- Packet LED stretcher
  signal pkt_led_r : std_logic := '0';
  signal pkt_cnt   : unsigned(23 downto 0) := (others => '0');

begin

  -- hook bypass inputs into internal signals
  rx_char <= i_rx_char;
  rx_dv   <= i_rx_dv;

  -- Extend 10-bit to 32-bit
  aqi_raw_32   <= std_logic_vector(resize(unsigned(aqi_raw), 32));
  temp_raw_32  <= std_logic_vector(resize(unsigned(temp_raw), 32));
  light_raw_32 <= std_logic_vector(resize(unsigned(light_raw), 32));

  -- PID width adaptation (10 -> 12)
  temp_filt_12 <= std_logic_vector(resize(unsigned(temp_filt), 12));

  --------------------------------------------------------------------
  -- Packet FSM Decoder
  --------------------------------------------------------------------
  fsm_decoder_inst : entity work.Packet_FSM_Decoder
    port map (
      i_Clk        => i_Clk,
      i_Reset_POR  => i_Reset_POR,
      i_rx_char    => rx_char,
      i_rx_dv      => rx_dv,
      o_AQI_val    => aqi_raw,
      o_TEMP_val   => temp_raw,
      o_LIGHT_val  => light_raw,
      o_data_ready => pkt_ready
    );

  --------------------------------------------------------------------
  -- Sliding window sum + saturator
  --------------------------------------------------------------------
  win_aqi : entity work.top_adjusted_window_sum
    generic map ( WINDOW_SIZE => WINDOW_SIZE_C )
    port map (
      clk       => i_Clk,
      A         => aqi_raw_32,
      MIN       => MIN_32,
      MAX       => MAX_32,
      A_valid   => pkt_ready,
      SUM       => aqi_sum_32,
      SUM_valid => aqi_sum_v
    );

  win_temp : entity work.top_adjusted_window_sum
    generic map ( WINDOW_SIZE => WINDOW_SIZE_C )
    port map (
      clk       => i_Clk,
      A         => temp_raw_32,
      MIN       => MIN_32,
      MAX       => MAX_32,
      A_valid   => pkt_ready,
      SUM       => temp_sum_32,
      SUM_valid => temp_sum_v
    );

  win_light : entity work.top_adjusted_window_sum
    generic map ( WINDOW_SIZE => WINDOW_SIZE_C )
    port map (
      clk       => i_Clk,
      A         => light_raw_32,
      MIN       => MIN_32,
      MAX       => MAX_32,
      A_valid   => pkt_ready,
      SUM       => light_sum_32,
      SUM_valid => light_sum_v
    );

  --------------------------------------------------------------------
  -- Convert SUM -> average -> 10-bit filtered
  --------------------------------------------------------------------
  process(i_Clk)
    variable avg : unsigned(31 downto 0);
  begin
    if rising_edge(i_Clk) then
      if i_Reset_POR = '1' then
        aqi_filt   <= (others => '0');
        temp_filt  <= (others => '0');
        light_filt <= (others => '0');
      else
        if aqi_sum_v = '1' then
          avg := unsigned(aqi_sum_32) / WINDOW_SIZE_C;
          aqi_filt <= std_logic_vector(resize(avg, 10));
        end if;

        if temp_sum_v = '1' then
          avg := unsigned(temp_sum_32) / WINDOW_SIZE_C;
          temp_filt <= std_logic_vector(resize(avg, 10));
        end if;

        if light_sum_v = '1' then
          avg := unsigned(light_sum_32) / WINDOW_SIZE_C;
          light_filt <= std_logic_vector(resize(avg, 10));
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Trend detector
  --------------------------------------------------------------------
  trend_temp : entity work.Trend_Detector
    port map (
      i_Clk          => i_Clk,
      i_Reset        => i_Reset_POR,
      i_filtered_val => temp_filt,
      i_valid        => temp_sum_v,
      o_trend        => temp_trend_i,
      o_spike_alert  => open
    );

  --------------------------------------------------------------------
  -- Z-score anomaly detectors (mu/sigma = 0 in your design)
  --------------------------------------------------------------------
  z_aqi : entity work.ZScore_AnomalyDetector
    port map (
      i_clk         => i_Clk,
      i_reset       => i_Reset_POR,
      i_sample      => aqi_filt,
      i_mu          => (others => '0'),
      i_sigma       => (others => '0'),
      i_valid       => aqi_sum_v,
      o_is_anomaly  => aqi_anom,
      o_zscore_sign => open
    );

  z_temp : entity work.ZScore_AnomalyDetector
    port map (
      i_clk         => i_Clk,
      i_reset       => i_Reset_POR,
      i_sample      => temp_filt,
      i_mu          => (others => '0'),
      i_sigma       => (others => '0'),
      i_valid       => temp_sum_v,
      o_is_anomaly  => temp_anom,
      o_zscore_sign => open
    );

  z_light : entity work.ZScore_AnomalyDetector
    port map (
      i_clk         => i_Clk,
      i_reset       => i_Reset_POR,
      i_sample      => light_filt,
      i_mu          => (others => '0'),
      i_sigma       => (others => '0'),
      i_valid       => light_sum_v,
      o_is_anomaly  => light_anom,
      o_zscore_sign => open
    );

  --------------------------------------------------------------------
  -- PID Controller
  --------------------------------------------------------------------
  pid_inst : entity work.PID_Controller
    port map (
      i_Clk          => i_Clk,
      i_Reset_POR    => i_Reset_POR,
      i_valid        => temp_sum_v,
      i_setpoint     => std_logic_vector(to_unsigned(200, 12)),
      i_measurement  => temp_filt_12,
      i_Kp           => std_logic_vector(to_unsigned(256, 12)),
      i_Ki           => std_logic_vector(to_unsigned(40, 12)),
      i_Kd           => std_logic_vector(to_unsigned(30, 12)),
      o_MV           => pid_mv,
      o_MV_saturated => open,
      o_valid        => pid_valid
    );

  --------------------------------------------------------------------
  -- Packet LED stretcher
  --------------------------------------------------------------------
  process(i_Clk)
  begin
    if rising_edge(i_Clk) then
      if i_Reset_POR = '1' then
        pkt_cnt   <= (others => '0');
        pkt_led_r <= '0';
      else
        if pkt_ready = '1' then
          pkt_cnt <= to_unsigned(5_000_000, pkt_cnt'length); -- ~50ms @ 100MHz
        elsif pkt_cnt /= 0 then
          pkt_cnt <= pkt_cnt - 1;
        end if;

        if pkt_cnt /= 0 then
          pkt_led_r <= '1';
        else
          pkt_led_r <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Outputs
  --------------------------------------------------------------------
  o_aqi_anomaly   <= aqi_anom;
  o_temp_anomaly  <= temp_anom;
  o_light_anomaly <= light_anom;

  o_temp_trend  <= temp_trend_i;
  o_pkt_led     <= pkt_led_r;
  o_pkt_ready   <= pkt_ready;

end RTL;
