library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PID_Controller_TB is
end entity;

architecture TB of PID_Controller_TB is

    --------------------------------------------------------------------
    -- DUT Declaration
    --------------------------------------------------------------------
    component PID_Controller is
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
    end component;

    --------------------------------------------------------------------
    -- Clock and Signals
    --------------------------------------------------------------------
    constant CLK_PERIOD : time := 10 ns;

    signal s_clk        : std_logic := '0';
    signal s_reset      : std_logic := '1';
    signal s_valid      : std_logic := '0';

    signal s_setpoint   : std_logic_vector(11 downto 0) := (others => '0');
    signal s_measurement: std_logic_vector(11 downto 0) := (others => '0');

    signal s_Kp         : std_logic_vector(11 downto 0) := (others => '0');
    signal s_Ki         : std_logic_vector(11 downto 0) := (others => '0');
    signal s_Kd         : std_logic_vector(11 downto 0) := (others => '0');

    signal w_MV         : std_logic_vector(11 downto 0);
    signal w_sat        : std_logic;
    signal w_valid_out  : std_logic;

begin

    --------------------------------------------------------------------
    -- Clock Generator
    --------------------------------------------------------------------
    s_clk <= not s_clk after CLK_PERIOD/2;

    --------------------------------------------------------------------
    -- DUT Instance
    --------------------------------------------------------------------
    DUT : PID_Controller
      port map(
        i_Clk          => s_clk,
        i_Reset_POR    => s_reset,
        i_valid        => s_valid,

        i_setpoint     => s_setpoint,
        i_measurement  => s_measurement,

        i_Kp           => s_Kp,
        i_Ki           => s_Ki,
        i_Kd           => s_Kd,

        o_MV           => w_MV,
        o_MV_saturated => w_sat,
        o_valid        => w_valid_out
      );

    --------------------------------------------------------------------
    -- Stimulus Process
    --------------------------------------------------------------------
    stim : process
        variable mv_int      : integer;
        variable plant_value : integer := 0;     -- NOW A VARIABLE
    begin
        ----------------------------------------------------------------
        -- Reset sequence
        ----------------------------------------------------------------
        wait for 40 ns;
        s_reset <= '0';

        ----------------------------------------------------------------
        -- PID Gains (scaled by FRACTION_BITS = 8)
        ----------------------------------------------------------------
        s_Kp <= std_logic_vector(to_unsigned(256, 12)); -- Kp = 1.0
        s_Ki <= std_logic_vector(to_unsigned( 40, 12)); -- Ki ? 0.15
        s_Kd <= std_logic_vector(to_unsigned( 30, 12)); -- Kd ? 0.12

        ----------------------------------------------------------------
        -- Apply a step on the setpoint (0 ? 200)
        ----------------------------------------------------------------
        s_setpoint   <= std_logic_vector(to_unsigned(200, 12));
        s_measurement<= std_logic_vector(to_unsigned(  0, 12));

        report "Starting PID step response simulation..." severity note;

        ----------------------------------------------------------------
        -- Main simulation loop: 200 samples
        ----------------------------------------------------------------
        for i in 0 to 200 loop

            ------------------------------------------------------------
            -- VALID pulse
            ------------------------------------------------------------
            s_valid <= '1';
            wait for CLK_PERIOD;
            s_valid <= '0';

            wait for CLK_PERIOD;

            ------------------------------------------------------------
            -- Convert MV to integer
            ------------------------------------------------------------
            mv_int := to_integer(signed(w_MV));

            ------------------------------------------------------------
            -- Simple plant model (integrator-like)
            ------------------------------------------------------------
            plant_value := plant_value + (mv_int / 40); -- smooth response

            -- clamp to 12-bit range
            if plant_value < 0 then plant_value := 0; end if;
            if plant_value > 4095 then plant_value := 4095; end if;

            ------------------------------------------------------------
            -- Update measurement signal
            ------------------------------------------------------------
            s_measurement <= std_logic_vector(to_unsigned(plant_value, 12));

            ------------------------------------------------------------
            -- Log information
            ------------------------------------------------------------
            report  "t=" & integer'image(i) &
                    "  Setpoint=200" &
                    "  Measurement=" & integer'image(plant_value) &
                    "  MV=" & integer'image(mv_int) &
                    "  Saturated=" & std_logic'image(w_sat)
                    severity note;

            wait for 30 ns;
        end loop;

        report "PID simulation finished." severity note;
        wait;
    end process;

end TB;
