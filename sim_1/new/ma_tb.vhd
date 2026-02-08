-- =============================================================================
-- TESTBENCH FOR MOVING AVERAGE FILTER (INTEGER, N=4)
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_MA_Filter is
end tb_MA_Filter;

architecture Behavioral of tb_MA_Filter is

    -- Component Declaration
    component MA_Filter is
        generic (
            DATA_WIDTH : integer := 10;
            N_SAMPLES  : integer := 4
        );
        port (
            i_Clk           : in  std_logic;
            i_Reset_POR     : in  std_logic;
            i_data_raw      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            i_data_valid    : in  std_logic;
            o_data_filtered : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- Testbench Signals
    constant c_CLK_PERIOD : time := 10 ns;

    signal s_Clk           : std_logic := '0';
    signal s_Reset_POR     : std_logic := '1';
    signal s_data_raw      : std_logic_vector(9 downto 0) := (others => '0');
    signal s_data_valid    : std_logic := '0';
    signal w_filtered_out  : std_logic_vector(9 downto 0);

begin

    -- Instantiate the DUT (Device Under Test)
    DUT : MA_Filter
        generic map (
            DATA_WIDTH => 10,
            N_SAMPLES  => 4
        )
        port map (
            i_Clk           => s_Clk,
            i_Reset_POR     => s_Reset_POR,
            i_data_raw      => s_data_raw,
            i_data_valid    => s_data_valid,
            o_data_filtered => w_filtered_out
        );

    -- Clock generation
    s_Clk <= not s_Clk after c_CLK_PERIOD / 2;

    ---------------------------------------------------------------------
    -- Stimulus process
    ---------------------------------------------------------------------
    p_stimulus : process
        -- Helper function: integer ? 10-bit slv
        function to_slv10(i : integer) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(i, 10));
        end function;
    begin
        -----------------------------------------------------
        -- RESET
        -----------------------------------------------------
        s_Reset_POR <= '1';
        wait for 50 ns;
        s_Reset_POR <= '0';
        wait for 20 ns;

        -----------------------------------------------------
        -- APPLY INPUT SAMPLES
        -- Values: 100, 200, 300, 400, then 50
        -----------------------------------------------------

        -- Sample 1: 100
        s_data_raw   <= to_slv10(100);
        s_data_valid <= '1';
        wait for c_CLK_PERIOD;
        s_data_valid <= '0';
        wait for 30 ns;

        -- Sample 2: 200
        s_data_raw   <= to_slv10(200);
        s_data_valid <= '1';
        wait for c_CLK_PERIOD;
        s_data_valid <= '0';
        wait for 30 ns;

        -- Sample 3: 300
        s_data_raw   <= to_slv10(300);
        s_data_valid <= '1';
        wait for c_CLK_PERIOD;
        s_data_valid <= '0';
        wait for 30 ns;

        -- Sample 4: 400
        s_data_raw   <= to_slv10(400);
        s_data_valid <= '1';
        wait for c_CLK_PERIOD;
        s_data_valid <= '0';
        wait for 40 ns;

        -- At this point the average should be:
        -- (100 + 200 + 300 + 400) / 4 = 250

        -- Sample 5: 50 (replaces oldest = 100)
        -- Window becomes [200, 300, 400, 50]
        -- Avg = (200 + 300 + 400 + 50) / 4 = 237
        s_data_raw   <= to_slv10(50);
        s_data_valid <= '1';
        wait for c_CLK_PERIOD;
        s_data_valid <= '0';
        wait for 40 ns;

        report "Simulation finished." severity note;
        wait;
    end process;

end Behavioral;
