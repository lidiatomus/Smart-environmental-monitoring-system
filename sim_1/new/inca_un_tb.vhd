library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Final_Top is
end entity;

architecture tb of tb_Final_Top is

  -- DUT ports
  signal i_Clk        : std_logic := '0';
  signal i_Reset_POR  : std_logic := '1';
  signal i_uart_rx    : std_logic := '1';

  signal o_aqi_anomaly   : std_logic;
  signal o_temp_anomaly  : std_logic;
  signal o_light_anomaly : std_logic;
  signal o_temp_trend    : std_logic_vector(1 downto 0);
  signal o_pkt_led       : std_logic;

  constant CLK_PERIOD : time := 10 ns; -- 100 MHz
  constant BAUD       : integer := 9600;
  constant BIT_PERIOD : time := 1 sec / BAUD;

  -- ---------- UART helpers (8N1, LSB first) ----------
  function c2slv8(c : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;

  procedure uart_send_byte(signal rx_line : out std_logic;
                           constant b     : in  std_logic_vector(7 downto 0)) is
  begin
    rx_line <= '1';
    wait for BIT_PERIOD;

    rx_line <= '0';                -- start
    wait for BIT_PERIOD;

    for i in 0 to 7 loop            -- data
      rx_line <= b(i);
      wait for BIT_PERIOD;
    end loop;

    rx_line <= '1';                -- stop
    wait for BIT_PERIOD;

    wait for BIT_PERIOD;           -- small inter-byte gap
  end procedure;

  procedure uart_send_string(signal rx_line : out std_logic;
                             constant s     : in string) is
  begin
    for k in s'range loop
      uart_send_byte(rx_line, c2slv8(s(k)));
    end loop;
  end procedure;

  -- integer'image inserts a leading space for positive numbers in VHDL.
  -- Strip spaces and send only digits and optional '-'.
  procedure uart_send_int(signal rx_line : out std_logic;
                          val : integer) is
    constant s : string := integer'image(val);
  begin
    for k in s'range loop
      if s(k) /= ' ' then
        uart_send_byte(rx_line, c2slv8(s(k)));
      end if;
    end loop;
  end procedure;

  -- Packet format that MATCHES YOUR Packet_FSM_Decoder:
  -- #A:<aqi>#T:<temp>#L:<light>#
  -- IMPORTANT: after finishing AQI with '#', the next character must be 'T' (NOT '#')
  procedure send_packet(signal rx_line : out std_logic;
                        aqi, temp, light : integer) is
  begin
    -- Start + AQI
    uart_send_string(rx_line, "#A:");
    uart_send_int(rx_line, aqi);
    uart_send_byte(rx_line, x"23"); -- '#'

    -- TEMP (no leading '#')
    uart_send_string(rx_line, "T:");
    uart_send_int(rx_line, temp);
    uart_send_byte(rx_line, x"23"); -- '#'

    -- LIGHT (no leading '#')
    uart_send_string(rx_line, "L:");
    uart_send_int(rx_line, light);
    uart_send_byte(rx_line, x"23"); -- '#'
  end procedure;

begin

  -- DUT
  dut : entity work.Final_Top
    port map (
      i_Clk           => i_Clk,
      i_Reset_POR     => i_Reset_POR,
      i_uart_rx       => i_uart_rx,
      o_aqi_anomaly   => o_aqi_anomaly,
      o_temp_anomaly  => o_temp_anomaly,
      o_light_anomaly => o_light_anomaly,
      o_temp_trend    => o_temp_trend,
      o_pkt_led       => o_pkt_led
    );

  -- clock
  p_clk : process
  begin
    while true loop
      i_Clk <= '0'; wait for CLK_PERIOD/2;
      i_Clk <= '1'; wait for CLK_PERIOD/2;
    end loop;
  end process;

  -- stimulus + checks
  p_stim : process
    procedure expect_pkt_led is
    begin
      -- give time for UART bytes to arrive + decoder to pulse pkt_ready + LED stretcher to latch
      wait for 10 ms;

      assert o_pkt_led = '1'
        report "ERROR: o_pkt_led did not go HIGH after packet. (pkt_ready likely never asserted)"
        severity failure;

      -- allow it to decay (your stretcher ~50ms)
      wait for 60 ms;
    end procedure;

  begin
    -- reset
    i_uart_rx   <= '1';
    i_Reset_POR <= '1';
    wait for 500 ns;
    i_Reset_POR <= '0';
    wait for 2 ms;

    -- Send a few packets
    send_packet(i_uart_rx, 129, 230, 234);
    expect_pkt_led;

    send_packet(i_uart_rx, 122, 270, 377);
    expect_pkt_led;

    send_packet(i_uart_rx, 235, 250, 250);
    expect_pkt_led;

    -- Trend test: rising temp (note Trend_Detector compares consecutive filtered values;
    -- you may need several packets before it changes depending on window behavior)
    send_packet(i_uart_rx, 130, 230, 300);
    wait for 20 ms;
    send_packet(i_uart_rx, 130, 240, 300);
    wait for 20 ms;
    send_packet(i_uart_rx, 130, 260, 300);
    wait for 20 ms;

    report "PASS: tb_Final_Top completed." severity note;
    wait;
  end process;

end architecture;
