library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_adjusted_window_sum_tb is
end top_adjusted_window_sum_tb;

architecture sim of top_adjusted_window_sum_tb is

    component top_adjusted_window_sum
        generic ( WINDOW_SIZE : integer := 5 );
        port(
            clk : in std_logic;

            A   : in std_logic_vector(31 downto 0);
            MIN : in std_logic_vector(31 downto 0);
            MAX : in std_logic_vector(31 downto 0);
            A_valid : in std_logic;

            SUM : out std_logic_vector(31 downto 0);
            SUM_valid : out std_logic
        );
    end component;

    signal clk : std_logic := '0';

    signal A       : std_logic_vector(31 downto 0);
    signal MIN     : std_logic_vector(31 downto 0);
    signal MAX     : std_logic_vector(31 downto 0);
    signal A_valid : std_logic := '0';

    signal SUM       : std_logic_vector(31 downto 0);
    signal SUM_valid : std_logic;

    constant clk_period : time := 10 ns;

begin

    -- Clock generation
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period / 2;
        clk <= '1';
        wait for clk_period / 2;
    end process;

    -- DUT
    DUT : top_adjusted_window_sum
        port map(
            clk => clk,
            A => A,
            MIN => MIN,
            MAX => MAX,
            A_valid => A_valid,
            SUM => SUM,
            SUM_valid => SUM_valid
        );

    stim : process
    begin

        MIN <= x"00000000";       -- 0
        MAX <= x"42C80000";       -- 100

        wait for 30 ns;

        ------------------------------------------------------------------
        -- A = 10
        ------------------------------------------------------------------
        A <= x"41200000";         -- 10
        A_valid <= '1';
        wait for clk_period;
        A_valid <= '0';
        wait for 40 ns;

        ------------------------------------------------------------------
        -- A = 120 ? saturates to 100
        ------------------------------------------------------------------
        A <= x"42F00000";
        A_valid <= '1';
        wait for clk_period;
        A_valid <= '0';
        wait for 40 ns;

        ------------------------------------------------------------------
        -- A = -5 ? saturates to 0
        ------------------------------------------------------------------
        A <= x"C0A00000";
        A_valid <= '1';
        wait for clk_period;
        A_valid <= '0';
        wait for 40 ns;

        ------------------------------------------------------------------
        -- A = 50
        ------------------------------------------------------------------
        A <= x"42480000";
        A_valid <= '1';
        wait for clk_period;
        A_valid <= '0';
        wait for 40 ns;

        ------------------------------------------------------------------
        -- A = 80
        ------------------------------------------------------------------
        A <= x"42A00000";
        A_valid <= '1';
        wait for clk_period;
        A_valid <= '0';
        wait for 50 ns;

        wait;
    end process;

end sim;
