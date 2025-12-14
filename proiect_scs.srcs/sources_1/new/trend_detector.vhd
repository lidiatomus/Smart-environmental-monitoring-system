library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Trend_Detector is
  generic (
    DATA_WIDTH      : integer := 10;      -- same width as your filtered AQI
    THRESHOLD_UP    : integer := 10;      -- minimal increase to call it UP
    THRESHOLD_DOWN  : integer := 10       -- minimal decrease to call it DOWN
  );
  port (
    i_Clk           : in  std_logic;
    i_Reset         : in  std_logic;

    i_filtered_val  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    i_valid         : in  std_logic;      -- pulse after each new filtered sample

    o_trend         : out std_logic_vector(1 downto 0);  
    --  "00" = steady
    --  "01" = trending up
    --  "10" = trending down

    o_spike_alert   : out std_logic       -- 1 = sudden AQI increase
  );
end Trend_Detector;


architecture RTL of Trend_Detector is

  signal r_prev_val   : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
  signal r_curr_val   : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');
  signal r_diff       : signed(DATA_WIDTH downto 0);  -- one extra bit for sign

  signal r_trend      : std_logic_vector(1 downto 0) := "00";
  signal r_spike      : std_logic := '0';

begin

  -- Compute difference
  r_diff <= signed(resize(r_curr_val, DATA_WIDTH+1)) -
            signed(resize(r_prev_val, DATA_WIDTH+1));

  process(i_Clk)
  begin
    if rising_edge(i_Clk) then

      if i_Reset = '1' then
        r_prev_val <= (others => '0');
        r_curr_val <= (others => '0');
        r_trend    <= "00";
        r_spike    <= '0';

      elsif i_valid = '1' then
        -- Shift samples
        r_prev_val <= r_curr_val;
        r_curr_val <= unsigned(i_filtered_val);

        -- TREND CLASSIFICATION
        if r_diff > to_signed(THRESHOLD_UP, DATA_WIDTH+1) then
          r_trend <= "01";   -- up
        elsif r_diff < to_signed(-THRESHOLD_DOWN, DATA_WIDTH+1) then
          r_trend <= "10";   -- down
        else
          r_trend <= "00";   -- steady
        end if;

        -- SPIKE ALERT (e.g., rapid AQI jump)
        if r_diff > to_signed(THRESHOLD_UP * 5, DATA_WIDTH+1) then
          r_spike <= '1';
        else
          r_spike <= '0';
        end if;

      end if;
    end if;
  end process;

  o_trend       <= r_trend;
  o_spike_alert <= r_spike;

end RTL;
