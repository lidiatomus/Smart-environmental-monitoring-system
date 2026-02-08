library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_RX is
  generic (
    g_CLKS_PER_BIT : integer := 10417  -- 100MHz/9600 
  );
  port (
    i_Clk       : in  std_logic;
    i_RX_Serial : in  std_logic;
    o_RX_DV     : out std_logic;
    o_RX_Byte   : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of UART_RX is

  type t_state is (IDLE, START, DATA, STOP, DONE);
  signal state      : t_state := IDLE;


  signal rx_ff1     : std_logic := '1';
  signal rx_sync    : std_logic := '1';

  signal clk_cnt    : integer range 0 to g_CLKS_PER_BIT-1 := 0;
  signal bit_idx    : integer range 0 to 7 := 0;
  signal rx_byte_r  : std_logic_vector(7 downto 0) := (others => '0');

  signal dv_r       : std_logic := '0';

begin

  -- outputs
  o_RX_Byte <= rx_byte_r;
  o_RX_DV   <= dv_r;

  -- synchronize async RX to i_Clk domain
  process(i_Clk)
  begin
    if rising_edge(i_Clk) then
      rx_ff1  <= i_RX_Serial;
      rx_sync <= rx_ff1;
    end if;
  end process;

  -- main UART RX FSM
  process(i_Clk)
  begin
    if rising_edge(i_Clk) then
      dv_r <= '0';  -- default: 1-clock pulse when DONE

      case state is

        when IDLE =>
          clk_cnt <= 0;
          bit_idx <= 0;

          -- detect start bit (line goes low)
          if rx_sync = '0' then
            state <= START;
          end if;

        when START =>
          -- wait to the middle of start bit
          if clk_cnt = (g_CLKS_PER_BIT-1)/2 then
            -- confirm still low (real start bit)
            if rx_sync = '0' then
              clk_cnt <= 0;
              state   <= DATA;
            else
              state   <= IDLE; -- glitch
            end if;
          else
            clk_cnt <= clk_cnt + 1;
          end if;

        when DATA =>
          -- wait full bit time, then sample in the middle (because we reset clk_cnt after mid-start)
          if clk_cnt = g_CLKS_PER_BIT-1 then
            clk_cnt <= 0;

            -- sample data bit (LSB first)
            rx_byte_r(bit_idx) <= rx_sync;

            if bit_idx = 7 then
              bit_idx <= 0;
              state   <= STOP;
            else
              bit_idx <= bit_idx + 1;
            end if;

          else
            clk_cnt <= clk_cnt + 1;
          end if;

        when STOP =>
          -- wait one bit time for stop bit, then check it
          if clk_cnt = g_CLKS_PER_BIT-1 then
            clk_cnt <= 0;

            -- stop bit should be '1'
            if rx_sync = '1' then
              state <= DONE;
            else
              state <= IDLE; -- framing error; drop byte
            end if;

          else
            clk_cnt <= clk_cnt + 1;
          end if;

        when DONE =>
          dv_r  <= '1';  -- 1 clock pulse
          state <= IDLE;

      end case;
    end if;
  end process;

end architecture;
