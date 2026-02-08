library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Final_Top_Data_TB is
end entity;

architecture TB of Final_Top_Data_TB is

    ------------------------------------------------------------------
    -- DUT
    ------------------------------------------------------------------
    component Final_Top is
        port (
            i_Clk        : in  std_logic;
            i_Reset_POR  : in  std_logic;

            -- simulation-only data feed
            i_sim_valid  : in  std_logic;
            i_sim_aqi    : in  std_logic_vector(9 downto 0);
            i_sim_temp   : in  std_logic_vector(9 downto 0);
            i_sim_light  : in  std_logic_vector(9 downto 0);

            o_aqi_anomaly   : out std_logic;
            o_temp_anomaly  : out std_logic;
            o_light_anomaly : out std_logic;
            o_temp_trend    : out std_logic_vector(1 downto 0)
        );
    end component;

    ------------------------------------------------------------------
    -- Clock
    ------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    signal s_clk   : std_logic := '0';
    signal s_reset : std_logic := '1';

    ------------------------------------------------------------------
    -- Stimulus signals
    ------------------------------------------------------------------
    signal s_valid : std_logic := '0';
    signal s_aqi   : std_logic_vector(9 downto 0);
    signal s_temp  : std_logic_vector(9 downto 0);
    signal s_light : std_logic_vector(9 downto 0);

    ------------------------------------------------------------------
    -- Outputs
    ------------------------------------------------------------------
    signal s_aqi_anom   : std_logic;
    signal s_temp_anom  : std_logic;
    signal s_light_anom : std_logic;
    signal s_temp_trend : std_logic_vector(1 downto 0);

begin

    ------------------------------------------------------------------
    -- Clock generation
    ------------------------------------------------------------------
    s_clk <= not s_clk after CLK_PERIOD/2;

    ------------------------------------------------------------------
    -- DUT instance
    ------------------------------------------------------------------
    DUT : Final_Top
        port map (
            i_Clk          => s_clk,
            i_Reset_POR    => s_reset,

            i_sim_valid    => s_valid,
            i_sim_aqi      => s_aqi,
            i_sim_temp     => s_temp,
            i_sim_light    => s_light,

            o_aqi_anomaly   => s_aqi_anom,
            o_temp_anomaly  => s_temp_anom,
            o_light_anomaly => s_light_anom,
            o_temp_trend    => s_temp_trend
        );

    ------------------------------------------------------------------
    -- Stimulus process
    ------------------------------------------------------------------
    stim : process
        procedure send_sample(aqi_i, temp_i, light_i : integer) is
        begin
            s_aqi   <= std_logic_vector(to_unsigned(aqi_i, 10));
            s_temp  <= std_logic_vector(to_unsigned(temp_i, 10));
            s_light <= std_logic_vector(to_unsigned(light_i, 10));

            s_valid <= '1';
            wait for CLK_PERIOD;
            s_valid <= '0';

            wait for CLK_PERIOD * 5;
        end procedure;
    begin

        report "Starting Final Top data-driven simulation";

        -- reset
        s_reset <= '1';
        wait for 100 ns;
        s_reset <= '0';
        wait for 50 ns;

        -- baseline (steady)
        send_sample(150, 250, 500);
        send_sample(150, 250, 500);
        send_sample(150, 250, 500);

        -- rising temperature
        send_sample(150, 255, 500);
        send_sample(150, 260, 500);

        -- anomaly
        send_sample(150, 900, 500);

        -- back to normal
        send_sample(150, 250, 500);
        send_sample(150, 250, 500);

        report "Simulation finished";
        wait;
    end process;

end architecture;
