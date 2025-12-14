library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 
entity sliding_window_sum_tb is
end entity;

architecture sim of sliding_window_sum_tb is

    component sliding_window_adder
        generic (WINDOW_SIZE : integer := 5);
        port (
            aclk : IN STD_LOGIC;
            s_axis_val_tvalid : IN STD_LOGIC;
            s_axis_val_tready : OUT STD_LOGIC;
            s_axis_val_tdata  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_sum_tvalid : OUT STD_LOGIC;
            m_axis_sum_tready : IN STD_LOGIC;
            m_axis_sum_tdata  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component;

    signal clk          : std_logic := '0';

    signal val_valid    : std_logic := '0';
    signal val_ready    : std_logic;
    signal val_data     : std_logic_vector(31 downto 0);

    signal sum_valid    : std_logic;
    signal sum_ready    : std_logic := '1';
    signal sum_data     : std_logic_vector(31 downto 0);

    constant clk_period : time := 10 ns;

begin

    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    inst : sliding_window_adder
        generic map (WINDOW_SIZE => 5)
        port map(
            aclk => clk,
            s_axis_val_tvalid => val_valid,
            s_axis_val_tready => val_ready,
            s_axis_val_tdata  => val_data,
            m_axis_sum_tvalid => sum_valid,
            m_axis_sum_tready => sum_ready,
            m_axis_sum_tdata  => sum_data
        );

    process
        
        procedure send_val(v : integer) is
        begin
            val_data  <= std_logic_vector(to_unsigned(v, 32));
            val_valid <= '1';

            wait until val_ready = '1' and rising_edge(clk);
            val_valid <= '0';

            wait until sum_valid = '1';
            wait for 10 ns;
        end procedure;
    begin

        wait for 50 ns;

        send_val(1);
        send_val(2);
        send_val(3);
        send_val(4);
        send_val(5);
        send_val(6);

        wait;
    end process;

end architecture;
