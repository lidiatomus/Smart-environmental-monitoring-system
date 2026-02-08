library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Final_Top_Debug_UART is
end entity;

architecture tb of tb_Final_Top_Debug_UART is

  signal i_Clk        : std_logic := '0';
  signal i_Reset_POR  : std_logic := '1';
  signal i_uart_rx    : std_logic := '1';

  signal o_aqi_anomaly   : std_logic;
  signal o_temp_anomaly  : std_logic;
  signal o_light_anomaly : std_logic;
  signal o_temp_trend    : std_logic_vector(1 downto 0);
  signal o_pkt_led       : std_logic;

  -- Debug outputs (must exist in Final_Top_Debug)
  signal o_pkt_ready     : std_logic;
  signal o_temp_filt     : std_logic_vector(9 downto 0);
  signal o_temp_avg      : std_logic_vector(9 downto 0);
  signal o_pid_mv        : std_logic_vector(11 downto 0);
  signal o_pid_valid     : std_logic;

  constant CLK_PERIOD : time := 10 ns; -- 100 MHz
  constant BAUD       : integer := 9600;
  constant BIT_PERIOD : time := 1 sec / BAUD;


  function c2slv8(c : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;

  procedure uart_send_byte(signal rx_line : out std_logic;
                           constant b     : in  std_logic_vector(7 downto 0)) is
  begin
    -- idle
    rx_line <= '1';
    wait for BIT_PERIOD;

    -- start bit
    rx_line <= '0';
    wait for BIT_PERIOD;

    -- data bits (LSB first)
    for i in 0 to 7 loop
      rx_line <= b(i);
      wait for BIT_PERIOD;
    end loop;

    -- stop bit
    rx_line <= '1';
    wait for BIT_PERIOD;

    -- inter-byte gap
    wait for BIT_PERIOD;
  end procedure;

  procedure uart_send_string(signal rx_line : out std_logic;
                             constant s     : in string) is
  begin
    for k in s'range loop
      uart_send_byte(rx_line, c2slv8(s(k)));
    end loop;
  end procedure;

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

 
  -- #A:<aqi>#T:<temp>#L:<light>#
  procedure send_packet(signal rx_line : out std_logic;
                        aqi, temp, light : integer) is
  begin
    uart_send_string(rx_line, "#A:");
    uart_send_int(rx_line, aqi);
    uart_send_byte(rx_line, x"23"); -- '#'

    uart_send_string(rx_line, "T:");
    uart_send_int(rx_line, temp);
    uart_send_byte(rx_line, x"23"); -- '#'

    uart_send_string(rx_line, "L:");
    uart_send_int(rx_line, light);
    uart_send_byte(rx_line, x"23"); -- '#'
  end procedure;

  procedure wait_pkt_led_seen(constant timeout : time := 200 ms) is
  begin
    wait until o_pkt_led = '1' for timeout;
    assert o_pkt_led = '1'
      report "ERROR: Packet sent but o_pkt_led never went HIGH (missed decode/UART)."
      severity failure;


    wait until rising_edge(i_Clk);

    -- wait until it goes low so next packet produces a new rising edge
    wait until o_pkt_led = '0' for timeout;
    wait until rising_edge(i_Clk);
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


  dut : entity work.Final_Top_Debug
    port map (
      i_Clk           => i_Clk,
      i_Reset_POR     => i_Reset_POR,
      i_uart_rx       => i_uart_rx,

      o_aqi_anomaly   => o_aqi_anomaly,
      o_temp_anomaly  => o_temp_anomaly,
      o_light_anomaly => o_light_anomaly,
      o_temp_trend    => o_temp_trend,
      o_pkt_led       => o_pkt_led,

      o_pkt_ready     => o_pkt_ready,
      o_temp_filt     => o_temp_filt,
      o_temp_avg      => o_temp_avg,
      o_pid_mv        => o_pid_mv,
      o_pid_valid     => o_pid_valid
    );


  p_clk : process
  begin
    while true loop
      i_Clk <= '0'; wait for CLK_PERIOD/2;
      i_Clk <= '1'; wait for CLK_PERIOD/2;
    end loop;
  end process;


  p_stim : process
    variable idx   : integer := 0;
    variable aqi_v : integer;
    variable t_v   : integer;
    variable l_v   : integer;

    variable seed : unsigned(31 downto 0) := x"12345678";

    procedure rand10(variable seed : inout unsigned(31 downto 0);
                     variable val  : out   integer) is
      variable x : unsigned(31 downto 0);
    begin
      x := seed * to_unsigned(1664525, 32) + to_unsigned(1013904223, 32);
      seed := x;
      val := to_integer(x(9 downto 0));
    end procedure;

    procedure send_and_log(aqi_i, temp_i, light_i : integer) is
    begin
      idx := idx + 1;

      send_packet(i_uart_rx, aqi_i, temp_i, light_i);
      wait_pkt_led_seen; -- <<<<<< FIX HERE

      if (idx mod 25) = 0 then
        report "pkt=" & integer'image(idx)
          & " A=" & integer'image(aqi_i)
          & " T=" & integer'image(temp_i)
          & " L=" & integer'image(light_i)
          & " trend=" & trend_str(o_temp_trend)
          & " pid_valid=" & std_logic'image(o_pid_valid)
          & " pid_mv=" & integer'image(to_integer(unsigned(o_pid_mv)))
          & " temp_filt=" & integer'image(to_integer(unsigned(o_temp_filt)))
          severity note;
      end if;
    end procedure;

  begin
    -- reset
    i_uart_rx   <= '1';
    i_Reset_POR <= '1';
    wait for 500 ns;
    i_Reset_POR <= '0';
    wait for 2 ms;

    report "===== UART stress test started =====" severity note;

    -- Phase 1: Warm-up
    for k in 1 to 20 loop
      send_and_log(120, 230, 300);
    end loop;

    -- Phase 2: Steady noise
    for k in 1 to 120 loop
      aqi_v := 120 + ((k mod 7) - 3);
      t_v   := 230 + ((k mod 5) - 2);
      l_v   := 350 + ((k mod 9) - 4);
      send_and_log(aqi_v, t_v, l_v);
    end loop;

    -- Phase 3: Ramp UP
    t_v := 200;
    for k in 1 to 60 loop
      t_v := t_v + 2;
      send_and_log(130, t_v, 360);
    end loop;

    -- Phase 4: Spikes
    for k in 1 to 60 loop
      if (k mod 10) /= 0 then
        send_and_log(150, 250, 400);
      else
        send_and_log(900, 320, 900);
      end if;
    end loop;

    -- Phase 5: Ramp DOWN
    t_v := 340;
    for k in 1 to 60 loop
      t_v := t_v - 2;
      send_and_log(140, t_v, 380);
    end loop;

    -- Phase 6: Random
    for k in 1 to 200 loop
      rand10(seed, aqi_v);
      rand10(seed, t_v);
      rand10(seed, l_v);
      send_and_log(aqi_v, t_v, l_v);
    end loop;

    report "===== PASS: UART stress test sent " & integer'image(idx) & " packets =====" severity note;

    wait for 20 ms;
    wait;
  end process;

end architecture;
