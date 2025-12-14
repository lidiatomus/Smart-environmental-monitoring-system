library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all; -- For simulation reporting

entity Final_Top_tb is
end entity;

architecture Behavioral of Final_Top_tb is

    -- Component Declaration for the UUT (Unit Under Test)
    component Final_Top is
        port (
            i_Clk          : in  std_logic;
            i_Reset_POR    : in  std_logic;
            i_uart_rx      : in  std_logic;
            o_aqi_anomaly  : out std_logic;
            o_temp_anomaly : out std_logic;
            o_light_anomaly: out std_logic;
            o_temp_trend   : out std_logic_vector(1 downto 0)
        );
    end component;

    -- Constants
    constant C_CLK_PERIOD : time := 10 ns; -- 100 MHz clock
    constant C_BAUD_RATE  : integer := 9600;
    -- Calculated minimum number of clock cycles per bit for UART
    -- (f_clk / BaudRate) = (100MHz / 9600) = 10416.6 clocks
    -- We will use a more standard simulation baud rate factor for simplicity
    -- A factor of 10 for f_clk / BaudRate is common in simple testbenches.
    constant C_CLKS_PER_BIT : integer := 10;
    constant C_BIT_TIME     : time := C_CLKS_PER_BIT * C_CLK_PERIOD; -- 100 ns

    -- Signals for UUT
    signal s_Clk           : std_logic := '0';
    signal s_Reset_POR     : std_logic := '1';
    signal s_uart_rx       : std_logic := '1'; -- Idle high

    signal s_aqi_anomaly   : std_logic;
    signal s_temp_anomaly  : std_logic;
    signal s_light_anomaly : std_logic;
    signal s_temp_trend    : std_logic_vector(1 downto 0);

    -- Helper function to convert 8-bit to a serial sequence
    -- Includes 1 Start Bit ('0') and 1 Stop Bit ('1')
    function to_serial(data : std_logic_vector(7 downto 0)) return std_logic_vector is
        -- Start (0), Data (7:0), Stop (1) = 10 bits
        constant BITS_TOTAL : integer := 10;
        variable result : std_logic_vector(BITS_TOTAL - 1 downto 0);
    begin
        result(0) := '0';              -- Start Bit
        result(8 downto 1) := data;    -- Data
        result(9) := '1';              -- Stop Bit
        return result;
    end function;

    -- Test sequence procedure
    procedure UART_TX (signal rx_line : out std_logic; constant data : std_logic_vector(7 downto 0)) is
        variable v_serial : std_logic_vector(9 downto 0);
    begin
        v_serial := to_serial(data);

        -- Transmit all 10 bits
        for i in 0 to 9 loop
            rx_line <= v_serial(i);
            wait for C_BIT_TIME;
        end loop;
    end procedure;

    -- Procedure to transmit a full packet: #A:xxx#T:xx#L:xxx#
    -- All values are expected to be 3 digits (10-bit max is 1023)
    procedure SEND_PACKET (
        signal rx_line : out std_logic;
        aqi_val  : integer;
        temp_val : integer;
        light_val: integer
    ) is
        -- Conversions (to_char is only available in VHDL-2008, using direct ASCII literals)
        -- We will assume a simple 3-digit ASCII conversion for the test
        -- Example: 250 -> '2', '5', '0'
        -- '2' is 50 in ASCII (0x32), '5' is 53 (0x35), '0' is 48 (0x30)
        variable aqi_d1, aqi_d2, aqi_d3 : std_logic_vector(7 downto 0);
        variable temp_d1, temp_d2, temp_d3 : std_logic_vector(7 downto 0);
        variable light_d1, light_d2, light_d3 : std_logic_vector(7 downto 0);
    begin

        -- Simple integer to 3-digit ASCII conversion for test
        aqi_d1   := std_logic_vector(to_unsigned( (aqi_val / 100) + 48, 8));
        aqi_d2   := std_logic_vector(to_unsigned( ((aqi_val mod 100) / 10) + 48, 8));
        aqi_d3   := std_logic_vector(to_unsigned( (aqi_val mod 10) + 48, 8));

        temp_d1  := std_logic_vector(to_unsigned( (temp_val / 100) + 48, 8));
        temp_d2  := std_logic_vector(to_unsigned( ((temp_val mod 100) / 10) + 48, 8));
        temp_d3  := std_logic_vector(to_unsigned( (temp_val mod 10) + 48, 8));

        light_d1 := std_logic_vector(to_unsigned( (light_val / 100) + 48, 8));
        light_d2 := std_logic_vector(to_unsigned( ((light_val mod 100) / 10) + 48, 8));
        light_d3 := std_logic_vector(to_unsigned( (light_val mod 10) + 48, 8));


        -- Start marker: # (0x23)
        UART_TX(rx_line, X"23");

        -- AQI: A:xxx#
        UART_TX(rx_line, X"41"); -- 'A'
        UART_TX(rx_line, X"3A"); -- ':'
        UART_TX(rx_line, aqi_d1);
        UART_TX(rx_line, aqi_d2);
        UART_TX(rx_line, aqi_d3);
        UART_TX(rx_line, X"23"); -- '#'

        -- TEMP: T:xxx#
        UART_TX(rx_line, X"54"); -- 'T'
        UART_TX(rx_line, X"3A"); -- ':'
        UART_TX(rx_line, temp_d1);
        UART_TX(rx_line, temp_d2);
        UART_TX(rx_line, temp_d3);
        UART_TX(rx_line, X"23"); -- '#'

        -- LIGHT: L:xxx#
        UART_TX(rx_line, X"4C"); -- 'L'
        UART_TX(rx_line, X"3A"); -- ':'
        UART_TX(rx_line, light_d1);
        UART_TX(rx_line, light_d2);
        UART_TX(rx_line, light_d3);
        UART_TX(rx_line, X"23"); -- '#'

        -- Wait a few clock cycles for the decoder and filters to process
        wait for 10 * C_CLK_PERIOD;

    end procedure;


begin

    -- Instantiate the Unit Under Test (UUT)
    uut : Final_Top
        port map (
            i_Clk           => s_Clk,
            i_Reset_POR     => s_Reset_POR,
            i_uart_rx       => s_uart_rx,
            o_aqi_anomaly   => s_aqi_anomaly,
            o_temp_anomaly  => s_temp_anomaly,
            o_light_anomaly => s_light_anomaly,
            o_temp_trend    => s_temp_trend
        );

    -- Clock generation process
    P_CLK : process
    begin
        s_Clk <= '0';
        wait for C_CLK_PERIOD / 2;
        s_Clk <= '1';
        wait for C_CLK_PERIOD / 2;
    end process;

    -- Test stimulus process
    P_STIMULUS : process
        -- Trend mapping (Assumed, based on typical detector: 00=Steady, 01=Rising, 10=Falling)
        constant C_TREND_RISING : std_logic_vector(1 downto 0) := "01";
        constant C_TREND_FALLING: std_logic_vector(1 downto 0) := "10";
        constant C_TREND_STEADY : std_logic_vector(1 downto 0) := "00";
    begin
        report "--- STARTING SIMULATION ---" severity NOTE;

        ----------------------------------------------------------------
        -- 1. Global Reset
        ----------------------------------------------------------------
        s_Reset_POR <= '1';
        wait for C_CLK_PERIOD * 10;
        s_Reset_POR <= '0';
        wait for C_CLK_PERIOD * 10;
        report "RESET COMPLETE" severity NOTE;

        ----------------------------------------------------------------
        -- 2. Establish a baseline (MA filter & Z-Score history)
        -- Send 5 "nominal" packets: AQI=150, TEMP=250, LIGHT=500
        ----------------------------------------------------------------
        report "Sending Baseline Packets..." severity NOTE;
        for i in 1 to 5 loop
            SEND_PACKET(s_uart_rx, 150, 250, 500);
            report "Packet " & integer'image(i) & " sent. AQI:150, TEMP:250, LIGHT:500" severity NOTE;
            assert s_temp_anomaly = '0' report "ERROR: Temp Anomaly triggered during baseline." severity error;
            assert s_temp_trend = C_TREND_STEADY report "ERROR: Trend not Steady during baseline." severity error;
        end loop;

        ----------------------------------------------------------------
        -- 3. Test Trend Detection (Rising)
        -- Send 3 rising packets: TEMP 255 -> 260 -> 265
        ----------------------------------------------------------------
        report "Testing Rising Trend..." severity NOTE;

        -- Packet 6: TEMP=255
        SEND_PACKET(s_uart_rx, 150, 255, 500);
        wait for 10 * C_CLK_PERIOD;
        assert s_temp_trend = C_TREND_STEADY report "ERROR: Trend should be Steady after 1st rising step." severity error;

        -- Packet 7: TEMP=260
        SEND_PACKET(s_uart_rx, 150, 260, 500);
        wait for 10 * C_CLK_PERIOD;
        assert s_temp_trend = C_TREND_RISING report "ERROR: Rising Trend not detected." severity error;

        -- Packet 8: TEMP=265
        SEND_PACKET(s_uart_rx, 150, 265, 500);
        wait for 10 * C_CLK_PERIOD;
        assert s_temp_trend = C_TREND_RISING report "ERROR: Rising Trend should persist." severity error;


        ----------------------------------------------------------------
        -- 4. Test Anomaly Detection (High Temp)
        -- Send an extremely high temperature value: TEMP=1000
        ----------------------------------------------------------------
        report "Testing Anomaly Detection..." severity NOTE;

        -- Packet 9: TEMP=1000 (Anomaly expected)
        SEND_PACKET(s_uart_rx, 150, 1000, 500);
        wait for 10 * C_CLK_PERIOD;
        assert s_temp_anomaly = '1' report "ERROR: Temp Anomaly (1000) was NOT detected." severity error;
        assert s_temp_trend = C_TREND_STEADY report "Check: Trend should settle/reset after a spike." severity note;

        ----------------------------------------------------------------
        -- 5. Return to baseline
        ----------------------------------------------------------------
        report "Returning to Baseline..." severity NOTE;
        for i in 10 to 12 loop
            SEND_PACKET(s_uart_rx, 150, 250, 500);
            report "Packet " & integer'image(i) & " sent." severity NOTE;
        end loop;

        -- Check anomaly clears
        wait for 10 * C_CLK_PERIOD;
        assert s_temp_anomaly = '0' report "ERROR: Temp Anomaly did not clear." severity error;

        ----------------------------------------------------------------
        -- 6. End Simulation
        ----------------------------------------------------------------
        report "--- SIMULATION COMPLETE. Check Waveform for PID_MV ---" severity NOTE;
        wait; -- Forever to stop the simulation

    end process;

end architecture Behavioral;