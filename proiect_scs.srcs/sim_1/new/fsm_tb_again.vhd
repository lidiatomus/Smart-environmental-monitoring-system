library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Packet_FSM_Decoder_TB is
end entity;

architecture Behavioral of Packet_FSM_Decoder_TB is

    --------------------------------------------------------------------------
    -- Component Declaration
    --------------------------------------------------------------------------
    component Packet_FSM_Decoder is
        generic (
            SENSOR_DATA_WIDTH : integer := 10;
            ACCUMULATOR_WIDTH : integer := 14
        );
        port (
            i_Clk        : in  std_logic;
            i_Reset_POR  : in  std_logic;
            i_rx_char    : in  std_logic_vector(7 downto 0);
            i_rx_dv      : in  std_logic;
            o_AQI_val    : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
            o_TEMP_val   : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
            o_LIGHT_val  : out std_logic_vector(SENSOR_DATA_WIDTH-1 downto 0);
            o_data_ready : out std_logic
        );
    end component;

    --------------------------------------------------------------------------
    -- Testbench Signals
    --------------------------------------------------------------------------
    constant C_CLK_PERIOD : time := 10 ns;

    signal s_Clk        : std_logic := '0';
    signal s_Reset_POR  : std_logic := '1';

    signal s_rx_char    : std_logic_vector(7 downto 0) := (others => '0');
    signal s_rx_dv      : std_logic := '0';

    signal w_AQI_val    : std_logic_vector(9 downto 0);
    signal w_TEMP_val   : std_logic_vector(9 downto 0);
    signal w_LIGHT_val  : std_logic_vector(9 downto 0);
    signal w_data_ready : std_logic;

    -- Expected Results
    constant C_EXPECTED_AQI   : integer := 438;
    constant C_EXPECTED_TEMP  : integer := 23;
    constant C_EXPECTED_LIGHT : integer := 670;

    -- Packet String
    constant C_PACKET_STRING : string := "#A:438#T:23#L:670#";

    --------------------------------------------------------------------------
    -- PROCEDURE to send a single ASCII character into the decoder
    --------------------------------------------------------------------------
    procedure SEND_CHAR(
        signal rx_char : out std_logic_vector(7 downto 0);
        signal rx_dv   : out std_logic;
        signal clk     : in  std_logic;
        i_char         : in  character
    ) is
    begin
        rx_char <= std_logic_vector(to_unsigned(character'pos(i_char), 8));
        rx_dv   <= '1';
        wait until rising_edge(clk);

        rx_dv   <= '0';
        rx_char <= (others => '0');
        wait for C_CLK_PERIOD * 2;
    end procedure;

begin

    --------------------------------------------------------------------------
    -- CLOCK GENERATION
    --------------------------------------------------------------------------
    clk_process : process
    begin
        s_Clk <= '0';
        wait for C_CLK_PERIOD/2;
        s_Clk <= '1';
        wait for C_CLK_PERIOD/2;
    end process clk_process;

    --------------------------------------------------------------------------
    -- Instantiate the Decoder
    --------------------------------------------------------------------------
    UUT : Packet_FSM_Decoder
        port map (
            i_Clk        => s_Clk,
            i_Reset_POR  => s_Reset_POR,
            i_rx_char    => s_rx_char,
            i_rx_dv      => s_rx_dv,
            o_AQI_val    => w_AQI_val,
            o_TEMP_val   => w_TEMP_val,
            o_LIGHT_val  => w_LIGHT_val,
            o_data_ready => w_data_ready
        );

    --------------------------------------------------------------------------
    -- Test Procedure
    --------------------------------------------------------------------------
    stimulus : process
        variable v_aqi_dec   : integer;
        variable v_temp_dec  : integer;
        variable v_light_dec : integer;
    begin

        report "===== Starting Packet FSM Decoder Test =====" severity note;

        ----------------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------------
        s_Reset_POR <= '1';
        wait for C_CLK_PERIOD * 5;
        s_Reset_POR <= '0';
        wait for C_CLK_PERIOD * 5;

        ----------------------------------------------------------------------
        -- TRANSMIT PACKET
        ----------------------------------------------------------------------
        report "Sending Packet: " & C_PACKET_STRING severity note;

        for i in C_PACKET_STRING'range loop
            SEND_CHAR(s_rx_char, s_rx_dv, s_Clk, C_PACKET_STRING(i));
        end loop;

        ----------------------------------------------------------------------
        -- WAIT FOR DECODER OUTPUT
        ----------------------------------------------------------------------
        wait until w_data_ready = '1';
        wait until rising_edge(s_Clk);  -- ensure stable outputs

        ----------------------------------------------------------------------
        -- Convert to integers
        ----------------------------------------------------------------------
        v_aqi_dec   := to_integer(unsigned(w_AQI_val));
        v_temp_dec  := to_integer(unsigned(w_TEMP_val));
        v_light_dec := to_integer(unsigned(w_LIGHT_val));

        ----------------------------------------------------------------------
        -- Print results
        ----------------------------------------------------------------------
        report "Decoded AQI   = " & integer'image(v_aqi_dec)
               & " (Expected " & integer'image(C_EXPECTED_AQI) & ")" severity note;

        report "Decoded TEMP  = " & integer'image(v_temp_dec)
               & " (Expected " & integer'image(C_EXPECTED_TEMP) & ")" severity note;

        report "Decoded LIGHT = " & integer'image(v_light_dec)
               & " (Expected " & integer'image(C_EXPECTED_LIGHT) & ")" severity note;

        ----------------------------------------------------------------------
        -- Assertions
        ----------------------------------------------------------------------
        assert v_aqi_dec = C_EXPECTED_AQI
            report "ERROR: AQI mismatch!" severity error;

        assert v_temp_dec = C_EXPECTED_TEMP
            report "ERROR: TEMP mismatch!" severity error;

        assert v_light_dec = C_EXPECTED_LIGHT
            report "ERROR: LIGHT mismatch!" severity error;

        ----------------------------------------------------------------------
        report "===== TEST PASSED SUCCESSFULLY =====" severity note;
        --------------------------------------------------------------------

        wait;
    end process;

end Behavioral;
