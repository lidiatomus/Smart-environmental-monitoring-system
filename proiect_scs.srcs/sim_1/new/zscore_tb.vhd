library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ZScore_AnomalyDetector_TB is
end entity;

architecture TB of ZScore_AnomalyDetector_TB is

    -- DUT Component Declaration
    component ZScore_AnomalyDetector is
      generic (
        DATA_WIDTH     : integer := 10;
        MU_WIDTH       : integer := 16;
        SIGMA_WIDTH    : integer := 16;
        THRESHOLD      : integer := 3
      );
      port (
        i_clk          : in  std_logic;
        i_reset        : in  std_logic;

        i_sample       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i_mu           : in  std_logic_vector(MU_WIDTH-1 downto 0);
        i_sigma        : in  std_logic_vector(SIGMA_WIDTH-1 downto 0);
        i_valid        : in  std_logic;

        o_is_anomaly   : out std_logic;
        o_zscore_sign  : out std_logic
      );
    end component;

    --------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    signal s_clk     : std_logic := '0';
    signal s_reset   : std_logic := '1';

    signal s_sample  : std_logic_vector(9 downto 0)  := (others => '0');
    signal s_mu      : std_logic_vector(15 downto 0) := (others => '0');
    signal s_sigma   : std_logic_vector(15 downto 0) := (others => '0');
    signal s_valid   : std_logic := '0';

    signal w_anomaly : std_logic;
    signal w_sign    : std_logic;

    -- Test values
    type t_array is array(0 to 6) of integer;
    constant TEST_SAMPLES : t_array :=
       -- normal, normal, anomaly(+), anomaly(-), normal
       (100, 102, 110, 150, 40, 98, 101);

begin

    --------------------------------------------------------------------
    -- CLOCK generator
    --------------------------------------------------------------------
    s_clk <= not s_clk after CLK_PERIOD/2;


    --------------------------------------------------------------------
    -- DUT instantiation
    --------------------------------------------------------------------
    DUT : ZScore_AnomalyDetector
      generic map (
        DATA_WIDTH  => 10,
        MU_WIDTH    => 16,
        SIGMA_WIDTH => 16,
        THRESHOLD   => 3     -- Z > 3 ? anomaly
      )
      port map(
        i_clk        => s_clk,
        i_reset      => s_reset,
        i_sample     => s_sample,
        i_mu         => s_mu,
        i_sigma      => s_sigma,
        i_valid      => s_valid,
        o_is_anomaly => w_anomaly,
        o_zscore_sign => w_sign
      );


    --------------------------------------------------------------------
    -- Stimulus Process
    --------------------------------------------------------------------
    stim : process
    begin
        report "===== STARTING Z-SCORE TESTBENCH =====" severity note;

        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------
        s_reset <= '1';
        wait for 50 ns;
        s_reset <= '0';
        wait for 20 ns;

        -- Set mean and sigma
        s_mu    <= std_logic_vector(to_unsigned(100, 16));  -- mean = 100
        s_sigma <= std_logic_vector(to_unsigned(5, 16));    -- sigma = 5

        ----------------------------------------------------------------
        -- Feed samples
        ----------------------------------------------------------------
        for i in TEST_SAMPLES'range loop

            s_sample <= std_logic_vector(to_unsigned(TEST_SAMPLES(i), 10));
            s_valid  <= '1';
            wait for CLK_PERIOD;
            s_valid  <= '0';

            wait for CLK_PERIOD * 2;

            report "Sample = " & integer'image(TEST_SAMPLES(i)) &
                   " | sign = " & std_logic'image(w_sign) &
                   " | anomaly = " & std_logic'image(w_anomaly)
                   severity note;
        end loop;

        report "===== Z-SCORE TEST COMPLETED =====" severity note;

        wait;
    end process;

end TB;
