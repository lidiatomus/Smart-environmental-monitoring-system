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

  -- Same format as your decoder TB
  constant C_PACKET_STRING : string := "#A:12#T:15#L:23#";

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

begin

  -- clock
  clk_process : process
  begin
    s_Clk <= '0'; wait for C_CLK_PERIOD/2;
    s_Clk <= '1'; wait for C_CLK_PERIOD/2;
  end process;

  -- DUT
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

  stimulus : process
  begin
    report "===== Starting Final_Top_NoUART Test =====" severity note;

    -- reset
    s_Reset_POR <= '1';
    wait for C_CLK_PERIOD * 5;
    s_Reset_POR <= '0';
    wait for C_CLK_PERIOD * 5;

    -- send packet chars (same as decoder TB)
    for i in C_PACKET_STRING'range loop
      SEND_CHAR(s_rx_char, s_rx_dv, s_Clk, C_PACKET_STRING(i));
    end loop;

    -- wait for decoder pulse
    wait until o_pkt_ready = '1';
    wait until rising_edge(s_Clk);

    -- pkt led should be high due to stretcher
    wait for 1 us;
    assert o_pkt_led = '1'
      report "ERROR: pkt_ready happened but o_pkt_led still LOW (stretcher issue)."
      severity failure;

    report "PASS: pkt_ready observed and o_pkt_led went high." severity note;

    wait for 5 ms;
    wait;
  end process;

end architecture;
