library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use std.env.stop;

entity axis_clock_converter_tb is
    end axis_clock_converter_tb;

architecture testbench of axis_clock_converter_tb is

    COMPONENT axis_clock_converter
        PORT (
            areset_n      : IN  STD_LOGIC;

            s_axis_aclk   : IN  STD_LOGIC;
            s_axis_tvalid : IN  STD_LOGIC;
            s_axis_tready : OUT STD_LOGIC;
            s_axis_tdata  : IN  STD_LOGIC_VECTOR(511 DOWNTO 0);

            m_axis_aclk   : IN  STD_LOGIC;
            m_axis_tvalid : OUT STD_LOGIC;
            m_axis_tready : IN  STD_LOGIC;
            m_axis_tdata  : OUT STD_LOGIC_VECTOR(511 DOWNTO 0)
        );
    END COMPONENT;

    -- Inputs
    signal areset_n      : std_logic := '0';
    signal s_axis_tvalid : STD_LOGIC;
    signal s_axis_tdata  : STD_LOGIC_VECTOR(511 DOWNTO 0);
    signal m_axis_tready : STD_LOGIC;

    -- Outputs
    signal s_axis_tready : STD_LOGIC;
    signal m_axis_tvalid : STD_LOGIC;
    signal m_axis_tdata  : STD_LOGIC_VECTOR(511 DOWNTO 0);

    -- Clock
    signal s_axis_aclk    : STD_LOGIC;
    signal m_axis_aclk    : STD_LOGIC;
    constant s_clk_period : time := 10 ns;
    constant m_clk_period : time := 5 ns;
    constant clk_period   : time := 5 ns;

begin
    s_clock : process
    begin
        s_axis_aclk <= '0';
        wait for s_clk_period/2;
        s_axis_aclk <= '1';
        wait for s_clk_period/2;
    end process;

    m_clock : process
    begin
        m_axis_aclk <= '0';
        wait for m_clk_period/2;
        m_axis_aclk <= '1';
        wait for m_clk_period/2;
    end process;

    clock_converter : axis_clock_converter
    PORT MAP (
        areset_n      => areset_n,

        s_axis_aclk   => s_axis_aclk,
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tready => s_axis_tready,
        s_axis_tdata  => s_axis_tdata,

        m_axis_aclk   => m_axis_aclk,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tready => m_axis_tready,
        m_axis_tdata  => m_axis_tdata
    );

    test : process
    begin
        -- Set initial values
        areset_n      <= '0';
        s_axis_tvalid <= '0';
        s_axis_tdata  <= (others => '0');
        m_axis_tready <= '0';

        -- Reset
        report "Sending reset";
        areset_n <= '0';
        wait for 16 * clk_period;
        assert (s_axis_tready = '0') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;
        assert (unsigned(m_axis_tdata) = 0) report "s_axis_tready not correct" severity failure;
        areset_n <= '1';
        wait for 2 * clk_period;

        assert (s_axis_tready = '1') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;
        assert (unsigned(m_axis_tdata) = 0) report "s_axis_tready not correct" severity failure;

        ---- Test sending data with receiver not ready
        -- Noise data
        s_axis_tdata <= std_logic_vector(to_unsigned(5, s_axis_tdata'length));
        wait for s_clk_period;
        assert (s_axis_tready = '1') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;

        -- Send
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_unsigned(1, s_axis_tdata'length));
        wait for s_clk_period;
        s_axis_tvalid <= '0';
        assert (s_axis_tready = '0') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;

        -- See data on line
        wait for 2 * m_clk_period;
        assert (s_axis_tready = '0') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '1') report "s_axis_tready not correct" severity failure;
        assert (unsigned(m_axis_tdata) = 1) report "s_axis_tready not correct" severity failure;

        -- Wait to read data
        wait for 2 * m_clk_period;

        -- Receive data
        m_axis_tready <= '1';
        wait for m_clk_period;
        m_axis_tready <= '0';
        assert (s_axis_tready = '0') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;

        wait for 3 * s_clk_period;
        assert (s_axis_tready = '1') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;

        -- Space between tests
        wait for 4 * clk_period;

        ---- Test sending data with receiver ready
        -- Send
        m_axis_tready <= '1';
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_unsigned(3, s_axis_tdata'length));
        wait for s_clk_period;
        s_axis_tvalid <= '0';
        assert (s_axis_tready = '0') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '1') report "s_axis_tready not correct" severity failure;
        assert (unsigned(m_axis_tdata) = 3) report "s_axis_tready not correct" severity failure;

        -- Receive data
        wait for m_clk_period;
        assert (s_axis_tready = '0') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;

        wait for 3 * s_clk_period;
        assert (s_axis_tready = '1') report "s_axis_tready not correct" severity failure;
        assert (m_axis_tvalid = '0') report "s_axis_tready not correct" severity failure;

        -- Space between tests
        wait for 4 * clk_period;

        -- Continuously send
        m_axis_tready <= '1';
        s_axis_tvalid <= '1';
        s_axis_tdata <= std_logic_vector(to_unsigned(10, s_axis_tdata'length));
        wait for 100 * clk_period;

        wait for 10 * clk_period;
        report "Simulation Finished";
        stop(0);
    end process;

end testbench;
