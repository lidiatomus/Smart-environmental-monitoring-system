library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MA_Filter is
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
end MA_Filter;

architecture RTL of MA_Filter is

  type t_buf is array (0 to N_SAMPLES-1) of unsigned(DATA_WIDTH-1 downto 0);
  signal r_buffer : t_buf := (others => (others => '0'));

  constant SUM_WIDTH : integer := DATA_WIDTH + 2;   -- log2(4)=2 bits
  signal r_sum       : unsigned(SUM_WIDTH-1 downto 0) := (others => '0');
  signal r_filtered  : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');

begin

  -- shift register
  process(i_Clk)
  begin
    if rising_edge(i_Clk) then
      if i_Reset_POR = '1' then
        r_buffer <= (others => (others => '0'));
      elsif i_data_valid = '1' then
        r_buffer(3) <= r_buffer(2);
        r_buffer(2) <= r_buffer(1);
        r_buffer(1) <= r_buffer(0);
        r_buffer(0) <= unsigned(i_data_raw);
      end if;
    end if;
  end process;

  -- registered summation + divide
  process(i_Clk)
  begin
    if rising_edge(i_Clk) then
      r_sum <= resize(unsigned(r_buffer(0)), SUM_WIDTH) +
               resize(unsigned(r_buffer(1)), SUM_WIDTH) +
               resize(unsigned(r_buffer(2)), SUM_WIDTH) +
               resize(unsigned(r_buffer(3)), SUM_WIDTH);

      r_filtered <= r_sum(SUM_WIDTH-1 downto 2);  -- divide by 4
    end if;
  end process;

  o_data_filtered <= std_logic_vector(r_filtered);

end RTL;
