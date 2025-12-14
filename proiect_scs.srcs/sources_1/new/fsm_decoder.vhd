-- =================================================================================
-- ENTITY: Packet_FSM_Decoder
-- Purpose: Receives UART ASCII stream, parses (#A:xxx#T:xx#L:xxx#),
--          converts ASCII digits to binary, and outputs integer sensor values.
-- =================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Packet_FSM_Decoder is
  generic (
    SENSOR_DATA_WIDTH : integer := 10;
    ACCUMULATOR_WIDTH : integer := 14
  );
  port (
    i_Clk       : in  std_logic;
    i_Reset_POR : in  std_logic;

    -- UART RX byte + data-valid input
    i_rx_char   : in  std_logic_vector(7 downto 0);
    i_rx_dv     : in  std_logic;

    -- Outputs
    o_AQI_val   : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
    o_TEMP_val  : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
    o_LIGHT_val : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
    o_data_ready: out std_logic
  );
end Packet_FSM_Decoder;


architecture RTL of Packet_FSM_Decoder is

  ---------------------------------------------------------------------------
  -- FSM States
  ---------------------------------------------------------------------------
  type t_SM_Main is (S_WAIT_START, S_READ_ID, S_WAIT_COLON, S_READ_VALUE, S_LATCH_DATA);
  signal r_SM_Main : t_SM_Main := S_WAIT_START;

  ---------------------------------------------------------------------------
  -- ASCII constants
  ---------------------------------------------------------------------------
  constant C_ASCII_HASH  : std_logic_vector(7 downto 0) := X"23"; -- '#'
  constant C_ASCII_COLON : std_logic_vector(7 downto 0) := X"3A"; -- ':'
  constant C_ASCII_ZERO  : std_logic_vector(7 downto 0) := X"30"; -- '0'

  constant C_ID_AQI   : std_logic_vector(7 downto 0) := X"41"; -- 'A'
  constant C_ID_TEMP  : std_logic_vector(7 downto 0) := X"54"; -- 'T'
  constant C_ID_LIGHT : std_logic_vector(7 downto 0) := X"4C"; -- 'L'

  ---------------------------------------------------------------------------
  -- Registers
  ---------------------------------------------------------------------------
  signal r_AQI_reg   : std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
  signal r_TEMP_reg  : std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
  signal r_LIGHT_reg : std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');

  type t_Sensor_ID is (ID_NONE, ID_AQI, ID_TEMP, ID_LIGHT);
  signal r_active_sensor : t_Sensor_ID := ID_NONE;

  signal r_current_value : unsigned(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');

  -- ASCII subtraction result
  signal w_subtraction_result : unsigned(7 downto 0);
  signal w_current_digit      : unsigned(3 downto 0);

  signal r_latch_pulse : std_logic := '0';

begin

  ----------------------------------------------------------------------------
  -- ASCII digit decode (8-bit subtract then extract lower nibble)
  ----------------------------------------------------------------------------
  w_subtraction_result <= unsigned(i_rx_char) - unsigned(C_ASCII_ZERO);
  w_current_digit      <= w_subtraction_result(3 downto 0);

  ----------------------------------------------------------------------------
  -- OUTPUT assignments
  ----------------------------------------------------------------------------
  o_AQI_val   <= r_AQI_reg(SENSOR_DATA_WIDTH-1 downto 0);
  o_TEMP_val  <= r_TEMP_reg(SENSOR_DATA_WIDTH-1 downto 0);
  o_LIGHT_val <= r_LIGHT_reg(SENSOR_DATA_WIDTH-1 downto 0);
  o_data_ready <= r_latch_pulse;

  ----------------------------------------------------------------------------
  -- MAIN FSM PROCESS
  ----------------------------------------------------------------------------
  p_parser : process(i_Clk)
    variable v_next_value : unsigned(ACCUMULATOR_WIDTH-1 downto 0);
  begin
    if rising_edge(i_Clk) then

      r_latch_pulse <= '0';  -- default

      -- Reset handling
      if i_Reset_POR = '1' then
        r_SM_Main       <= S_WAIT_START;
        r_active_sensor <= ID_NONE;
        r_current_value <= (others => '0');
        r_AQI_reg       <= (others => '0');
        r_TEMP_reg      <= (others => '0');
        r_LIGHT_reg     <= (others => '0');

      elsif i_rx_dv = '1' then

        case r_SM_Main is

          --------------------------------------------------------------------
          when S_WAIT_START =>
            r_current_value <= (others => '0');
            if i_rx_char = C_ASCII_HASH then
              r_SM_Main <= S_READ_ID;
            end if;

          --------------------------------------------------------------------
          when S_READ_ID =>
            r_current_value <= (others => '0');
            if    i_rx_char = C_ID_AQI   then r_active_sensor <= ID_AQI;   r_SM_Main <= S_WAIT_COLON;
            elsif i_rx_char = C_ID_TEMP  then r_active_sensor <= ID_TEMP;  r_SM_Main <= S_WAIT_COLON;
            elsif i_rx_char = C_ID_LIGHT then r_active_sensor <= ID_LIGHT; r_SM_Main <= S_WAIT_COLON;
            else
              r_SM_Main <= S_WAIT_START;
            end if;

          --------------------------------------------------------------------
          when S_WAIT_COLON =>
            if i_rx_char = C_ASCII_COLON then
              r_SM_Main <= S_READ_VALUE;
            else
              r_SM_Main <= S_WAIT_START;
            end if;

          --------------------------------------------------------------------
          when S_READ_VALUE =>
            -- END-OF-FIELD
            if i_rx_char = C_ASCII_HASH then
              r_SM_Main <= S_LATCH_DATA;

            -- NUMERIC DIGIT
          elsif w_current_digit <= 9 then
    -- Multiply-by-10 implemented with shift-and-add:
    -- 10 * x = (x * 8) + (x * 2) = (x sll 3) + (x sll 1)
    v_next_value :=
        (r_current_value sll 3) +      -- x * 8
        (r_current_value sll 1) +      -- x * 2
        resize(w_current_digit, ACCUMULATOR_WIDTH);

    r_current_value <= v_next_value;

            

            else
              r_SM_Main <= S_WAIT_START;
            end if;

          --------------------------------------------------------------------
          when S_LATCH_DATA =>
            -- latch parsed value
            case r_active_sensor is
              when ID_AQI   => r_AQI_reg   <= std_logic_vector(r_current_value(ACCUMULATOR_WIDTH-1 downto 0));
              when ID_TEMP  => r_TEMP_reg  <= std_logic_vector(r_current_value(ACCUMULATOR_WIDTH-1 downto 0));
              when ID_LIGHT => r_LIGHT_reg <= std_logic_vector(r_current_value(ACCUMULATOR_WIDTH-1 downto 0));
              when others   => null;
            end case;

            -- decide next state
            if r_active_sensor = ID_LIGHT then
              r_latch_pulse <= '1';       -- packet finished
              r_SM_Main     <= S_WAIT_START;
            else
              r_SM_Main     <= S_READ_ID; -- next field begins
            end if;

            r_active_sensor <= ID_NONE;
            r_current_value <= (others => '0');

          --------------------------------------------------------------------
          when others =>
            r_SM_Main <= S_WAIT_START;

        end case;
      end if; -- rx_dv

    end if; -- clk
  end process;

end RTL;
