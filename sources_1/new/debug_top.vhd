library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Final_Top_Debug is
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

    -- Debug
    o_pkt_led       : out std_logic;
    o_pkt_ready     : out std_logic;

    -- Extra debug outputs
    o_temp_filt     : out std_logic_vector(9 downto 0);
    o_temp_avg      : out std_logic_vector(9 downto 0); -- same as filt in MA_Filter design
    o_pid_mv        : out std_logic_vector(11 downto 0);
    o_pid_valid     : out std_logic
  );
end entity;

architecture RTL of Final_Top_Debug is

  -- UART RX
  signal rx_char : std_logic_vector(7 downto 0);
  signal rx_dv   : std_logic;

  -- Decoder outputs
  signal aqi_raw   : std_logic_vector(9 downto 0);
  signal temp_raw  : std_logic_vector(9 downto 0);
  signal light_raw : std_logic_vector(9 downto 0);
  signal pkt_ready : std_logic;

  -- Filtered values
  signal aqi_filt   : std_logic_vector(9 downto 0) := (others => '0');
  signal temp_filt  : std_logic_vector(9 downto 0) := (others => '0');
  signal light_filt : std_logic_vector(9 downto 0) := (others => '0');

  -- PID width adaptation
  signal temp_filt_12 : std_logic_vector(11 downto 0);

  -- Trend
  signal temp_trend_i : std_logic_vector(1 downto 0);

  -- Anomalies
  signal aqi_anom   : std_logic := '0';
  signal temp_anom  : std_logic := '0';
  signal light_anom : std_logic := '0';

  -- PID
  signal pid_mv    : std_logic_vector(11 downto 0) := (others => '0');
  signal pid_valid : std_logic := '0';
  signal led_cnt  : unsigned(23 downto 0) := (others => '0'); -- 24 bits enough for 10,000,000
signal pkt_led_r: std_logic := '0';


begin

  temp_filt_12 <= std_logic_vector(resize(unsigned(temp_filt), 12));

  -- UART RX
  uart_rx_inst : entity work.UART_RX
    generic map (
      g_CLKS_PER_BIT => 10417
    )
    port map (
      i_Clk       => i_Clk,
      i_RX_Serial => i_uart_rx,
      o_RX_DV     => rx_dv,
      o_RX_Byte   => rx_char
    );

  -- Packet decoder
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

  -- Moving average filters (your MA_Filter)
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

  -- Trend detector
  trend_temp : entity work.Trend_Detector
    port map (
      i_Clk          => i_Clk,
      i_Reset        => i_Reset_POR,
      i_filtered_val => temp_filt,
      i_valid        => pkt_ready,
      o_trend        => temp_trend_i,
      o_spike_alert  => open
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

  -- TEMP: for MA_Filter design, "sum" isn't available; expose avg=filt
  o_temp_filt <= temp_filt;
  o_temp_avg  <= temp_filt;

  -- Outputs
  o_aqi_anomaly   <= aqi_anom;   -- (see mu/sigma section)
  o_temp_anomaly  <= temp_anom;
  o_light_anomaly <= light_anom;

  o_temp_trend <= temp_trend_i;

  -- Debug pulses
  process(i_Clk)
begin
  if rising_edge(i_Clk) then
    if i_Reset_POR = '1' then
      led_cnt   <= (others => '0');
      pkt_led_r <= '0';
    else
      -- reload on each packet
      if pkt_ready = '1' then
        led_cnt <= to_unsigned(10_000_000, led_cnt'length); -- 100 ms
      elsif led_cnt /= 0 then
        led_cnt <= led_cnt - 1;
      end if;

      if led_cnt /= 0 then
        pkt_led_r <= '1';
      else
        pkt_led_r <= '0';
      end if;
    end if;
  end if;
end process;

o_pkt_led <= pkt_led_r;


  o_pid_mv    <= pid_mv;
  o_pid_valid <= pid_valid;

end RTL;
