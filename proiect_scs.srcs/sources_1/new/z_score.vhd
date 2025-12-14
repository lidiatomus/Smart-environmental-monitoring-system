library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ZScore_AnomalyDetector is
  generic (
    DATA_WIDTH     : integer := 10;   -- width of filtered input sample
    MU_WIDTH       : integer := 16;   -- width of mean value
    SIGMA_WIDTH    : integer := 16;   -- width of standard deviation
    THRESHOLD      : integer := 3     -- Z-score threshold (Z > 3 => anomaly)
  );
  port (
    i_clk          : in  std_logic;
    i_reset        : in  std_logic;

    i_sample       : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- filtered sample
    i_mu           : in  std_logic_vector(MU_WIDTH-1 downto 0);   -- mean
    i_sigma        : in  std_logic_vector(SIGMA_WIDTH-1 downto 0);-- std deviation
    i_valid        : in  std_logic;                                -- strobe input

    o_is_anomaly   : out std_logic;  -- 1 when |x - ?| > threshold * ?
    o_zscore_sign  : out std_logic   -- 1 = positive deviation, 0 = negative
  );
end ZScore_AnomalyDetector;


architecture Behavioral of ZScore_AnomalyDetector is

  --------------------------------------------------------------------------
  -- INTERNAL SIGNALS
  --------------------------------------------------------------------------
  signal s_sample        : signed(MU_WIDTH-1 downto 0);
  signal s_mu            : signed(MU_WIDTH-1 downto 0);
  signal s_sigma         : unsigned(SIGMA_WIDTH-1 downto 0);

  signal s_diff          : signed(MU_WIDTH-1 downto 0);
  signal s_absdiff       : unsigned(MU_WIDTH-1 downto 0);

  signal s_threshold_val : unsigned(SIGMA_WIDTH-1 downto 0);
  signal s_threshold_sigma : unsigned(SIGMA_WIDTH-1 downto 0); -- threshold * sigma

begin

  --------------------------------------------------------------------------
  -- CAST INPUTS TO PROPER NUMERIC TYPES
  --------------------------------------------------------------------------
  s_sample <= signed(resize(unsigned(i_sample), MU_WIDTH));
  s_mu     <= signed(i_mu);
  s_sigma  <= unsigned(i_sigma);

  --------------------------------------------------------------------------
  -- COMPUTE DIFFERENCE AND ITS ABSOLUTE VALUE
  --------------------------------------------------------------------------
  s_diff    <= s_sample - s_mu;
  s_absdiff <= unsigned(abs(s_diff));

  --------------------------------------------------------------------------
  -- COMPUTE (threshold * sigma)
  -- Fully synthesizable, no std_logic_vector involved.
  --------------------------------------------------------------------------
  s_threshold_val   <= to_unsigned(THRESHOLD, SIGMA_WIDTH);
-- Compute threshold * sigma (32-bit result ? resize to SIGMA_WIDTH)
  s_threshold_sigma <= resize(s_threshold_val * s_sigma, SIGMA_WIDTH);

  --------------------------------------------------------------------------
  -- MAIN PROCESS
  --------------------------------------------------------------------------
  process(i_clk)
  begin
    if rising_edge(i_clk) then

      if i_reset = '1' then
        o_is_anomaly  <= '0';
        o_zscore_sign <= '0';

      elsif i_valid = '1' then

        --------------------------------------------------------------------
        -- DETERMINE SIGN OF Z-SCORE
        --------------------------------------------------------------------
        if s_diff > 0 then
          o_zscore_sign <= '1';
        else
          o_zscore_sign <= '0';
        end if;

        --------------------------------------------------------------------
        -- ANOMALY TEST: |x - ?| > threshold * ?
        --------------------------------------------------------------------
        if s_absdiff > resize(s_threshold_sigma, MU_WIDTH) then
          o_is_anomaly <= '1';
        else
          o_is_anomaly <= '0';
        end if;

      end if;

    end if;
  end process;

end Behavioral;
