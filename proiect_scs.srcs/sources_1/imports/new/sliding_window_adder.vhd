library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity sliding_window_adder is
    Generic (
        WINDOW_SIZE : integer := 5
    );
    Port ( 
        aclk : IN STD_LOGIC;
        s_axis_val_tvalid : IN STD_LOGIC;
        s_axis_val_tready : OUT STD_LOGIC;
        s_axis_val_tdata  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_sum_tvalid : OUT STD_LOGIC;
        m_axis_sum_tready : IN STD_LOGIC;
        m_axis_sum_tdata  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
end sliding_window_adder;


architecture Behavioral of sliding_window_adder is


    type state_type is (S_READ, S_WRITE);
    signal state : state_type := S_READ;

    type window_array is array (0 to WINDOW_SIZE-1) 
        of std_logic_vector(31 downto 0);
    signal window : window_array := (others => (others => '0'));

    signal sum : std_logic_vector(31 downto 0) := (others => '0');
    signal ptr : integer range 0 to WINDOW_SIZE-1 := 0;

    signal internal_ready : std_logic := '0';
    signal external_ready : std_logic := '0';

begin

    internal_ready <= '1' when state = S_READ else '0';
    external_ready <= internal_ready and s_axis_val_tvalid;
    s_axis_val_tready <= external_ready;

    m_axis_sum_tvalid <= '1' when state = S_WRITE else '0';
    m_axis_sum_tdata  <= sum;

    process(aclk)
    begin
        if rising_edge(aclk) then
            case state is
                when S_READ =>
                    if external_ready = '1' then
                        sum <= sum + s_axis_val_tdata - window(ptr);
                        window(ptr) <= s_axis_val_tdata;
                        if ptr < WINDOW_SIZE-1 then
                            ptr <= ptr + 1;
                        else
                            ptr <= 0;
                        end if;
                        state <= S_WRITE;
                    end if;
                when S_WRITE =>
                    if m_axis_sum_tready = '1' then
                        state <= S_READ;
                    end if;
            end case;
        end if;
    end process;

end Behavioral;
