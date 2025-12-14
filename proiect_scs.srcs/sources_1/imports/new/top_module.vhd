library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_adjusted_window_sum is
    generic(
        WINDOW_SIZE : integer := 5
    );
    port(
        clk  : in  std_logic;

        -- Inputs
        A    : in  std_logic_vector(31 downto 0);
        MIN  : in  std_logic_vector(31 downto 0);
        MAX  : in  std_logic_vector(31 downto 0);
        A_valid : in std_logic;

        -- Output
        SUM  : out std_logic_vector(31 downto 0);
        SUM_valid : out std_logic
    );
end top_adjusted_window_sum;

architecture Structural of top_adjusted_window_sum is

    ------------------------------------------------------------------
    -- Internal signals connecting the 2 modules
    ------------------------------------------------------------------
    signal sat_data  : std_logic_vector(31 downto 0);
    signal sat_valid : std_logic;
    signal sat_ready : std_logic;

begin

    ------------------------------------------------------------------
    -- 1. SATURATOR
    ------------------------------------------------------------------
    saturator_inst : entity work.saturator
        port map(
            aclk => clk,

            s_axis_val_tdata  => A,
            s_axis_val_tvalid => A_valid,
            s_axis_val_tready => open,

            s_axis_min_tdata  => MIN,
            s_axis_min_tvalid => A_valid,
            s_axis_min_tready => open,

            s_axis_max_tdata  => MAX,
            s_axis_max_tvalid => A_valid,
            s_axis_max_tready => open,

            m_axis_result_tdata  => sat_data,
            m_axis_result_tvalid => sat_valid,
            m_axis_result_tready => sat_ready
        );

    ------------------------------------------------------------------
    -- 2. SLIDING WINDOW ADDER
    ------------------------------------------------------------------
    window_inst : entity work.sliding_window_adder
        generic map( WINDOW_SIZE => WINDOW_SIZE )
        port map(
            aclk => clk,

            s_axis_val_tdata  => sat_data,
            s_axis_val_tvalid => sat_valid,
            s_axis_val_tready => sat_ready,

            m_axis_sum_tdata  => SUM,
            m_axis_sum_tvalid => SUM_valid,
            m_axis_sum_tready => '1'
        );

end Structural;
