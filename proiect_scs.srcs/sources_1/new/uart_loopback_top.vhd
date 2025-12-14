library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_loopback_top is
    Port (
        clk        : in  std_logic;                  -- 100 MHz clock 
        led        : out std_logic_vector(7 downto 0); -- LED output (received byte)
        led_pulse  : out std_logic;                  -- Pulse on new data received 
        
        -- UART Pins (for physical connection/loopback)
        tx         : out std_logic;                  -- Serial Output (A18)
        rx         : in  std_logic                   -- Serial Input (A17)
    );
end uart_loopback_top;

architecture Behavioral of uart_loopback_top is

    constant CLKS_PER_BIT : integer := 10417; 

    component UART_TX is
        generic (g_CLKS_PER_BIT : integer);
        port (  i_Clk : in std_logic; 
                i_TX_DV : in std_logic;
                i_TX_Byte : in std_logic_vector(7 downto 0);
                o_TX_Active : out std_logic; 
                o_TX_Serial : out std_logic;    
                o_TX_Done : out std_logic);
    end component UART_TX;

    component UART_RX is
        generic (g_CLKS_PER_BIT : integer);
        port (  i_Clk : in std_logic;     
                i_RX_Serial : in std_logic;
                o_RX_DV : out std_logic;  
                o_RX_Byte : out std_logic_vector(7 downto 0));
    end component UART_RX;



    signal s_tx_data    : std_logic_vector(7 downto 0) := "11110000"; -- Test pattern
    signal s_tx_start   : std_logic := '0'; 
    signal s_tx_done    : std_logic := '1';    -- Ready to transmit
    
    
    signal s_tx_line    : std_logic;        
    signal s_rx_line    : std_logic;
    signal s_rx_data    : std_logic_vector(7 downto 0);
    signal s_rx_valid   : std_logic;        

    -- Control Signals
    signal counter      : integer range 0 to 100000001 := 0;
    constant MAX_COUNT  : integer := 100000000; -- ~1 second pause
    
    -- POWER-ON RESET SIGNALS 
    signal s_por_reset  : std_logic := '1'; -- Starts active-high
    signal r_por_counter: integer range 0 to 100 := 0; 
    constant c_POR_COUNT : integer := 50; -- Hold reset for 50 clock cycles

begin

    -- POWER-ON RESET GENERATOR 
    p_POR_GEN: process(clk)
    begin
        if rising_edge(clk) then
            if r_por_counter < c_POR_COUNT then
                s_por_reset <= '1';
                r_por_counter <= r_por_counter + 1;
            else
                s_por_reset <= '0';
            end if;
        end if;
    end process p_POR_GEN;

    s_rx_line <= rx; 

    tx <= s_tx_line;

    TX_inst : component UART_TX
        generic map (
            g_CLKS_PER_BIT => CLKS_PER_BIT
        )
        port map (
            i_Clk       => clk,
            i_TX_DV     => s_tx_start,
            i_TX_Byte   => s_tx_data,
            o_TX_Active => open,
            o_TX_Serial => s_tx_line, 
            o_TX_Done   => s_tx_done
        );

    RX_inst : component UART_RX
        generic map (
            g_CLKS_PER_BIT => CLKS_PER_BIT
        )
        port map (
            i_Clk       => clk,
            i_RX_Serial => s_rx_line, 
            o_RX_DV     => s_rx_valid,
            o_RX_Byte   => s_rx_data
        );

    -- display received byte on LEDs
    led <= s_rx_data;

    -- controls when the next byte is sent
    p_TX_CONTROL: process(clk)
    begin
        if rising_edge(clk) then
            if s_por_reset = '1' then 
                counter     <= 0;
                s_tx_start  <= '0';
                s_tx_done   <= '1'; 
            elsif counter = MAX_COUNT and s_tx_done = '1' then
                counter     <= 0;
                s_tx_start  <= '1';  
            elsif s_tx_start = '1' then
                s_tx_start  <= '0';
            else
                counter <= counter + 1;
            end if;
        end if;
    end process p_TX_CONTROL;

    -- generates a pulse on the led_pulse output when data is received
    p_RX_PULSE: process(clk)
    begin
        if rising_edge(clk) then
            if s_por_reset = '1' then
                led_pulse <= '0';
            elsif s_rx_valid = '1' then
                led_pulse <= '1'; 
            else
                led_pulse <= '0';
            end if;
        end if;
    end process p_RX_PULSE;

end Behavioral;