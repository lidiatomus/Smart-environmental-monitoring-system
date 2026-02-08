library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_test_top is
    Port (
        clk        : in  std_logic;               -- 100 MHz
        reset      : in  std_logic;
        rx         : in  std_logic;               -- UART input from Arduino (voltage-divided)
        led        : out std_logic_vector(7 downto 0); -- Show received byte
        led_pulse  : out std_logic                -- Blinks when new data is received
    );
end uart_test_top;

architecture Behavioral of uart_test_top is

    -- Signals from UART receiver
    signal data_out   : std_logic_vector(7 downto 0);
    signal data_valid : std_logic;

    -- Internal LED pulse signal
    signal pulse_reg  : std_logic := '0';

begin

    -- Instantiate UART receiver
    uart_inst : entity work.uart_rx
        port map (
            clk        => clk,
            reset      => reset,
            rx         => rx,
            data_out   => data_out,
            data_valid => data_valid
        );

    -- Store last received byte on LEDs
    led <= data_out;

    -- LED pulse logic (brief blink on new data)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pulse_reg <= '0';
            elsif data_valid = '1' then
                pulse_reg <= '1';
            else
                pulse_reg <= '0'; -- one clock cycle pulse
            end if;
        end if;
    end process;

    led_pulse <= pulse_reg;
    --led <= "10101010";  -- see if LEDs light up statically

end Behavioral;
