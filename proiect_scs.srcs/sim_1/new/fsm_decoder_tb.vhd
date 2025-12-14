-- ===============================================================================
-- ENTITY: Packet_FSM_Decoder_TB
-- Purpose: Verifies the Packet FSM Decoder functionality, including ASCII-to-Binary
--          conversion and correct latching of sensor values based on the protocol.
-- ===============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity Packet_FSM_Decoder_TB is
end Packet_FSM_Decoder_TB;

architecture Behavioral of Packet_FSM_Decoder_TB is

  -- Component Declaration (Matching Packet_FSM_Decoder.vhd)
  component Packet_FSM_Decoder is
    generic (
      SENSOR_DATA_WIDTH : integer := 10;
      ACCUMULATOR_WIDTH : integer := 14
    );
    port (
      i_Clk       : in  std_logic;
      i_Reset_POR : in  std_logic;
      i_rx_char   : in  std_logic_vector(7 downto 0);
      i_rx_dv     : in  std_logic;
      o_AQI_val   : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
      o_TEMP_val  : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
      o_LIGHT_val : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
      o_data_ready: out std_logic
    );
  end component Packet_FSM_Decoder;

  -- Constants and Signals
  constant C_CLK_PERIOD : time := 10 ns;
  constant C_DATA_WIDTH : integer := 10;
  constant C_ACC_WIDTH  : integer := 14;

  signal s_Clk       : std_logic := '0';
  signal s_Reset_POR : std_logic := '1';
  signal s_rx_char   : std_logic_vector(7 downto 0) := (others => '0');
  signal s_rx_dv     : std_logic := '0';
  
  -- Outputs to monitor
  signal w_AQI_val   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal w_TEMP_val  : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal w_LIGHT_val : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal w_data_ready: std_logic;

  -- Expected Decimal Values
  constant C_EXPECTED_AQI   : integer := 438;
  constant C_EXPECTED_TEMP  : integer := 23;
  constant C_EXPECTED_LIGHT : integer := 670;

  -- The simulated packet string: "#A:438#T:23#L:670#" (18 characters total)
  constant C_PACKET_STRING : string := "#A:438#T:23#L:670#";

  -- *******************************************************************
  -- CONCURRENT CLOCK GENERATOR (Placed outside any process)
  -- *******************************************************************
  s_Clk <= not s_Clk after C_CLK_PERIOD / 2;

  -- Procedure to simulate UART Data Valid pulse for one character
  procedure SEND_CHAR (
    i_char : in character
  ) is
  begin
    s_rx_char <= std_logic_vector(to_unsigned(character'pos(i_char), 8));
    s_rx_dv <= '1';
    wait until rising_edge(s_Clk);
    s_rx_dv <= '0';
    s_rx_char <= (others => '0'); -- Clear character input
    wait for C_CLK_PERIOD * 2;
  end procedure SEND_CHAR;

begin

  -- Instantiate the Unit Under Test (UUT)
  UUT : Packet_FSM_Decoder
    generic map (
      SENSOR_DATA_WIDTH => C_DATA_WIDTH,
      ACCUMULATOR_WIDTH => C_ACC_WIDTH
    )
    port map (
      i_Clk       => s_Clk,
      i_Reset_POR => s_Reset_POR,
      i_rx_char   => s_rx_char,
      i_rx_dv     => s_rx_dv,
      o_AQI_val   => w_AQI_val,
      o_TEMP_val  => w_TEMP_val,
      o_LIGHT_val => w_LIGHT_val,
      o_data_ready=> w_data_ready
    );

  -- Stimulus Process
  p_stimulus : process
    variable v_aqi_dec, v_temp_dec, v_light_dec : integer;
  begin
    report "--- Starting FSM Decoder Test ---" severity note;

    -- 1. Initial Reset (Active High)
    s_Reset_POR <= '1';
    wait for C_CLK_PERIOD * 5;
    s_Reset_POR <= '0';
    wait for C_CLK_PERIOD * 5;

    -- 2. Send the Full Packet String
    report "Sending Packet: " & C_PACKET_STRING severity note;

    for i in C_PACKET_STRING'range loop
      SEND_CHAR(C_PACKET_STRING(i));
    end loop;

    -- 3. Wait for the data_ready pulse to assert and latch the results
    wait until w_data_ready = '1' for 100 ns;

    -- 4. Convert and Verify Results
    v_aqi_dec   := to_integer(unsigned(w_AQI_val));
    v_temp_dec  := to_integer(unsigned(w_TEMP_val));
    v_light_dec := to_integer(unsigned(w_LIGHT_val));

    report "--- Verification Results ---" severity note;
    report "Received AQI:   " & integer'image(v_aqi_dec)   & " (Expected: " & integer'image(C_EXPECTED_AQI)   & ")" severity note;
    report "Received TEMP:  " & integer'image(v_temp_dec)  & " (Expected: " & integer'image(C_EXPECTED_TEMP)  & ")" severity note;
    report "Received LIGHT: " & integer'image(v_light_dec) & " (Expected: " & integer'image(C_EXPECTED_LIGHT) & ")" severity note;

    -- Final Assertions
    assert v_aqi_dec = C_EXPECTED_AQI
      report "TEST FAILED: AQI value mismatch." severity error;
    assert v_temp_dec = C_EXPECTED_TEMP
      report "TEST FAILED: TEMP value mismatch." severity error;
    assert v_light_dec = C_EXPECTED_LIGHT
      report "TEST FAILED: LIGHT value mismatch." severity error;

    report "--- FSM Decoder Test Passed ---" severity note;

    wait;
  end process p_stimulus;

end Behavioral;