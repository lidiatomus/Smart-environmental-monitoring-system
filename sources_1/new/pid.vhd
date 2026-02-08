library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PID_Controller is
  generic (
    DATA_WIDTH    : integer := 12;  
    COEFF_WIDTH   : integer := 12;  
    ACC_WIDTH     : integer := 24;  
    OUT_WIDTH     : integer := 12;  
    FRACTION_BITS : integer := 8    
  );
  port (
    i_Clk         : in  std_logic;
    i_Reset_POR   : in  std_logic;
    i_valid       : in  std_logic;

    i_setpoint    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    i_measurement : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    i_Kp          : in  std_logic_vector(COEFF_WIDTH-1 downto 0);
    i_Ki          : in  std_logic_vector(COEFF_WIDTH-1 downto 0);
    i_Kd          : in  std_logic_vector(COEFF_WIDTH-1 downto 0);

    o_MV          : out std_logic_vector(OUT_WIDTH-1 downto 0);
    o_MV_saturated: out std_logic;
    o_valid       : out std_logic
  );
end PID_Controller;

architecture RTL of PID_Controller is

  constant PROD_WIDTH : integer := DATA_WIDTH + COEFF_WIDTH;  -- P, I, D products width 
  constant SUM_WIDTH  : integer := ACC_WIDTH + 2;
  signal s_error, s_prev_error, s_d_error :
         signed(DATA_WIDTH-1 downto 0) := (others => '0');   -- error terms
  signal s_Kp, s_Ki, s_Kd : signed(COEFF_WIDTH-1 downto 0);   -- coefficients
  signal s_P_prod, s_I_prod, s_D_prod :
         signed(PROD_WIDTH-1 downto 0) := (others => '0');   -- P, I, D products before shifting
  signal s_I_acc : signed(ACC_WIDTH-1 downto 0) := (others => '0');   -- integral accumulator
  signal s_sum_raw : signed(SUM_WIDTH-1 downto 0) := (others => '0');   -- summed PID output before clipping

  -- final output
  signal s_MV      : signed(OUT_WIDTH-1 downto 0) := (others => '0');
  signal s_sat     : std_logic := '0';

begin

  -- cast 
  s_Kp <= signed(i_Kp);
  s_Ki <= signed(i_Ki);
  s_Kd <= signed(i_Kd);

  process(i_Clk)
    variable v_P_scaled, v_I_scaled, v_D_scaled :
             signed(PROD_WIDTH-1-FRACTION_BITS downto 0);

    variable v_sum      : signed(SUM_WIDTH-1 downto 0);
    variable v_I_next   : signed(ACC_WIDTH-1 downto 0);
    variable v_out      : signed(OUT_WIDTH-1 downto 0);
    variable v_sat      : std_logic;
  begin
    if rising_edge(i_Clk) then

      o_valid <= '0';

      if i_Reset_POR = '1' then
        s_error      <= (others => '0');
        s_prev_error <= (others => '0');
        s_d_error    <= (others => '0');
        s_I_acc      <= (others => '0');
        s_P_prod     <= (others => '0');
        s_I_prod     <= (others => '0');
        s_D_prod     <= (others => '0');
        s_sum_raw    <= (others => '0');
        s_MV         <= (others => '0');
        s_sat        <= '0';

      elsif i_valid = '1' then

        -- error & derivative
        s_error      <= signed(i_setpoint) - signed(i_measurement);
        s_d_error    <= s_error - s_prev_error;
        s_prev_error <= s_error;

       
        -- P / I / D products
        s_P_prod <= s_error   * s_Kp;
        s_I_prod <= s_error   * s_Ki;
        s_D_prod <= s_d_error * s_Kd;

        -- shift right by FRACTION_BITS
        v_P_scaled := s_P_prod(PROD_WIDTH-1 downto FRACTION_BITS);
        v_I_scaled := s_I_prod(PROD_WIDTH-1 downto FRACTION_BITS);
        v_D_scaled := s_D_prod(PROD_WIDTH-1 downto FRACTION_BITS);

        -- integral update 
        v_I_next :=
          s_I_acc + resize(v_I_scaled, ACC_WIDTH);

        -- clamp integral
        if v_I_next > to_signed(2**(ACC_WIDTH-1)-1, ACC_WIDTH) then
          v_I_next := to_signed(2**(ACC_WIDTH-1)-1, ACC_WIDTH);
        elsif v_I_next < to_signed(-2**(ACC_WIDTH-1), ACC_WIDTH) then
          v_I_next := to_signed(-2**(ACC_WIDTH-1), ACC_WIDTH);
        end if;
        s_I_acc <= v_I_next;

        --sum P + I + D 
        v_sum :=
          resize(v_P_scaled, SUM_WIDTH) +
          resize(v_D_scaled, SUM_WIDTH) +
          resize(v_I_next,   SUM_WIDTH);

        s_sum_raw <= v_sum;

        --output
        v_sat := '0';
        if v_sum > to_signed(2**(OUT_WIDTH-1)-1, SUM_WIDTH) then
          v_out := to_signed(2**(OUT_WIDTH-1)-1, OUT_WIDTH);
          v_sat := '1';
        elsif v_sum < to_signed(-2**(OUT_WIDTH-1), SUM_WIDTH) then
          v_out := to_signed(-2**(OUT_WIDTH-1), OUT_WIDTH);
          v_sat := '1';
        else
          v_out := resize(v_sum, OUT_WIDTH);
        end if;

        s_MV  <= v_out;
        s_sat <= v_sat;

        o_valid <= '1';

      end if;
    end if;
  end process;

  o_MV          <= std_logic_vector(s_MV);
  o_MV_saturated<= s_sat;

end RTL;
