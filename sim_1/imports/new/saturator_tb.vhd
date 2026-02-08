library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity saturator_tb is
end saturator_tb;

architecture sim of saturator_tb is

    component saturator
      Port(
        aclk : IN STD_LOGIC;
        s_axis_val_tvalid : IN STD_LOGIC;
        s_axis_val_tready : OUT STD_LOGIC;
        s_axis_val_tdata  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_max_tvalid : IN STD_LOGIC;
        s_axis_max_tready : OUT STD_LOGIC;
        s_axis_max_tdata  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_min_tvalid : IN STD_LOGIC;
        s_axis_min_tready : OUT STD_LOGIC;
        s_axis_min_tdata  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_result_tvalid : OUT STD_LOGIC;
        m_axis_result_tready : IN STD_LOGIC;
        m_axis_result_tdata  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
      );
    end component;

    signal clk : std_logic := '0';

    signal val_valid : std_logic := '0';
    signal val_ready : std_logic;
    signal val_data  : std_logic_vector(31 downto 0);

    signal min_valid : std_logic := '0';
    signal min_ready : std_logic;
    signal min_data  : std_logic_vector(31 downto 0);

    signal max_valid : std_logic := '0';
    signal max_ready : std_logic;
    signal max_data  : std_logic_vector(31 downto 0);

    signal out_valid : std_logic;
    signal out_ready : std_logic := '1';
    signal out_data  : std_logic_vector(31 downto 0);

    constant clk_period : time := 10 ns;

begin

    -- Clock
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- DUT
    DUT : saturator
      port map(
        aclk => clk,

        s_axis_val_tvalid => val_valid,
        s_axis_val_tready => val_ready,
        s_axis_val_tdata  => val_data,

        s_axis_min_tvalid => min_valid,
        s_axis_min_tready => min_ready,
        s_axis_min_tdata  => min_data,

        s_axis_max_tvalid => max_valid,
        s_axis_max_tready => max_ready,
        s_axis_max_tdata  => max_data,

        m_axis_result_tvalid => out_valid,
        m_axis_result_tready => out_ready,
        m_axis_result_tdata  => out_data
      );

    -- Stimulus
    stim : process
    begin

        wait for 50 ns;

        -------------------------------------------------------------
        -- Test 1: val = 10
        -------------------------------------------------------------
        min_data <= x"00000000";   -- 0
        max_data <= x"42C80000";   -- 100
        val_data <= x"41200000";   -- 10

        min_valid <= '1';
        max_valid <= '1';
        val_valid <= '1';

        wait until rising_edge(clk) and val_ready = '1';

        min_valid <= '0';
        max_valid <= '0';
        val_valid <= '0';

        wait until out_valid = '1';
        wait for 30 ns;


        -------------------------------------------------------------
        -- Test 2: val = 120 (clamped to 100)
        -------------------------------------------------------------
        min_data <= x"00000000";  
        max_data <= x"42C80000";  
        val_data <= x"42F00000";   -- 120

        min_valid <= '1';
        max_valid <= '1';
        val_valid <= '1';

        wait until rising_edge(clk) and val_ready = '1';

        min_valid <= '0';
        max_valid <= '0';
        val_valid <= '0';

        wait until out_valid = '1';
        wait for 30 ns;


        -------------------------------------------------------------
        -- Test 3: val = -5 (clamped to 0)
        -------------------------------------------------------------
        min_data <= x"00000000";  
        max_data <= x"42C80000";  
        val_data <= x"C0A00000";  -- -5

        min_valid <= '1';
        max_valid <= '1';
        val_valid <= '1';

        wait until rising_edge(clk) and val_ready = '1';

        min_valid <= '0';
        max_valid <= '0';
        val_valid <= '0';

        wait until out_valid = '1';
        wait for 30 ns;


        -------------------------------------------------------------
        -- Test 4: val = 50
        -------------------------------------------------------------
        min_data <= x"00000000";  
        max_data <= x"42C80000";  
        val_data <= x"42480000";  -- 50

        min_valid <= '1';
        max_valid <= '1';
        val_valid <= '1';

        wait until rising_edge(clk) and val_ready = '1';

        min_valid <= '0';
        max_valid <= '0';
        val_valid <= '0';

        wait until out_valid = '1';
        wait for 30 ns;

        wait;
    end process;

end sim;
