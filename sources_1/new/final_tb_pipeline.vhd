library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Final_Top is
  port (
    i_Clk        : in  std_logic;
    i_Reset_POR  : in  std_logic;

    -- UART interface
    i_uart_rx    : in  std_logic;

    -- Status / alerts
    o_aqi_anomaly   : out std_logic;
    o_temp_anomaly  : out std_logic;
    o_light_anomaly : out std_logic;

    o_temp_trend    : out std_logic_vector(1 downto 0);

    -- Debug LED: packet received
    o_pkt_led       : out std_logic
  );
end entity;

architecture RTL of Final_Top is

  -- UART RX
  signal rx_char : std_logic_vector(7 downto 0);
  signal rx_dv   : std_logic;

  -- FSM Decoder outputs
  signal aqi_raw   : std_logic_vector(9 downto 0);
  signal temp_raw  : std_logic_vector(9 downto 0);
  signal light_raw : std_logic_vector(9 downto 0);
  signal pkt_ready : std_logic;

  -- Filtered values
  signal aqi_filt   : std_logic_vector(9 downto 0);
  signal temp_filt  : std_logic_vector(9 downto 0);
  signal light_filt : std_logic_vector(9 downto 0);

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

  -- Packet LED register
  signal pkt_led_r : std_logic := '0';

begin

  temp_filt_12 <= std_logic_vector(resize(unsigned(temp_filt), 12));

  -- UART RX
  uart_rx_inst : entity work.uart_rx
    port map (
      i_clk       => i_Clk,
      i_rx_serial => i_uart_rx,
      o_rx_dv     => rx_dv,
      o_rx_byte   => rx_char
    );

  -- FSM Decoder
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

  -- Moving average filters
  ma_aqi : entity work.MA_Filter
    port map (
      i_Clk           => i_Clk,
      i_Reset_POR     => i_Reset_POR,
      i_data_raw      => aqi_raw,
      i_data_valid    => pkt_ready,
      o_data_filtered => aqi_filt
    );

  ma_temp : entity work.MA_Filter
    port map (
      i_Clk           => i_Clk,
      i_Reset_POR     => i_Reset_POR,
      i_data_raw      => temp_raw,
      i_data_valid    => pkt_ready,
      o_data_filtered => temp_filt
    );

  ma_light : entity work.MA_Filter
    port map (
      i_Clk           => i_Clk,
      i_Reset_POR     => i_Reset_POR,
      i_data_raw      => light_raw,
      i_data_valid    => pkt_ready,
      o_data_filtered => light_filt
    );

  -- Trend detector (temperature)
  trend_temp : entity work.Trend_Detector
    port map (
      i_Clk          => i_Clk,
      i_Reset        => i_Reset_POR,
      i_filtered_val => temp_filt,
      i_valid        => pkt_ready,
      o_trend        => temp_trend_i,
      o_spike_alert  => open
    );

  -- Z-score anomaly detectors
z_aqi : entity work.ZScore_AnomalyDetector
  port map (
    i_clk        => i_Clk,
    i_reset      => i_Reset_POR,
    i_sample     => aqi_filt,
    i_mu         => std_logic_vector(to_unsigned(120, 16)),
    i_sigma      => std_logic_vector(to_unsigned(40, 16)),
    i_valid      => aqi_sum_v,
    o_is_anomaly => aqi_anom,
    o_zscore_sign=> open
  );

z_temp : entity work.ZScore_AnomalyDetector
  port map (
    i_clk        => i_Clk,
    i_reset      => i_Reset_POR,
    i_sample     => temp_filt,
    i_mu         => std_logic_vector(to_unsigned(230, 16)),
    i_sigma      => std_logic_vector(to_unsigned(25, 16)),
    i_valid      => temp_sum_v,
    o_is_anomaly => temp_anom,
    o_zscore_sign=> open
  );

z_light : entity work.ZScore_AnomalyDetector
  port map (
    i_clk        => i_Clk,
    i_reset      => i_Reset_POR,
    i_sample     => light_filt,
    i_mu         => std_logic_vector(to_unsigned(300, 16)),
    i_sigma      => std_logic_vector(to_unsigned(80, 16)),
    i_valid      => light_sum_v,
    o_is_anomaly => light_anom,
    o_zscore_sign=> open
  );

  -- PID controller
  pid_inst : entity work.PID_Controller
    port map (
      i_Clk          => i_Clk,
      i_Reset_POR    => i_Reset_POR,
      i_valid        => pkt_ready,
      i_setpoint     => std_logic_vector(to_unsigned(200, 12)),
      i_measurement  => temp_filt_12,
      i_Kp           => std_logic_vector(to_unsigned(256, 12)),
      i_Ki           => std_logic_vector(to_unsigned(40, 12)),
      i_Kd           => std_logic_vector(to_unsigned(30, 12)),
      o_MV           => pid_mv,
      o_MV_saturated => open,
      o_valid        => pid_valid
    );

  -- Packet LED pulse
  process(i_Clk)
  begin
    if rising_edge(i_Clk) then
      if i_Reset_POR = '1' then
        pkt_led_r <= '0';
      else
        pkt_led_r <= pkt_ready;
      end if;
    end if;
  end process;

  -- Outputs
  o_aqi_anomaly   <= aqi_anom;
  o_temp_anomaly  <= temp_anom;
  o_light_anomaly <= light_anom;
  o_temp_trend    <= temp_trend_i;
  o_pkt_led <= rx_dv;

end RTL;
