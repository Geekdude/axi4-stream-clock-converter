----------------------------------------------------------------------------------
-- Company: The University of Tennessee, Knoxville
-- Engineer: Aaron Young
--
-- Design Name: AXIS Clock Converter
-- Project Name: DANNA 2
-- Tool Versions: Vivado 2016.4 or later
-- Description: Synchronizer to allow AXIS to cross clock domains.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axis_clock_converter is
    GENERIC (
        DATA_WIDTH  : positive := 512
    );
    PORT (
        areset_n      : IN  STD_LOGIC;

        s_axis_aclk   : IN  STD_LOGIC;
        s_axis_tvalid : IN  STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tdata  : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);

        m_axis_aclk   : IN  STD_LOGIC;
        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tready : IN  STD_LOGIC;
        m_axis_tdata  : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0)
    );
end axis_clock_converter;

architecture Behavioral of axis_clock_converter is

    component synchronizer
        generic (
            RESET_VALUE    : std_logic := '0'; -- reset value of all flip-flops in the chain
            NUM_FLIP_FLOPS : natural := 2 -- number of flip-flops in the synchronizer chain
        );
        port(
            rst      : in std_logic; -- asynchronous, high-active
            clk      : in std_logic; -- destination clock
            data_in  : in std_logic;
            data_out : out std_logic
        );
    end component;

    -- Internal signals
    signal areset                 : std_logic;

    signal s_valid_toggle         : std_logic;
    signal m_valid_toggle         : std_logic;
    signal m_valid_toggle_f       : std_logic;

    signal s_ready                : std_logic;
    signal s_data                 : std_logic_vector(DATA_WIDTH-1 downto 0 );

    signal s_read_toggle          : std_logic;
    signal m_read_toggle          : std_logic;

    signal m_read_pulse           : std_logic;
    signal m_valid                : std_logic;
    signal m_valid_l              : std_logic;

    -- State Machine Signals
    type s_state_t is (S_IDLE, S_SEND);
    signal s_state : s_state_t;

begin
    ----------------------------------------------------------------------------
    ---- Asynchronous Domain
    ----------------------------------------------------------------------------

    -- Active high reset signal
    areset <= not areset_n;

    ----------------------------------------------------------------------------
    ---- Synchronizers
    ----------------------------------------------------------------------------

    -- Synchronizer to convert the valid toggle from the S clock domain to the M clock domain.
    valid_sync : synchronizer
    generic map (
        reset_value    => '0',
        num_flip_flops => 2
    )
    port map (
        rst      => areset,
        clk      => m_axis_aclk,
        data_in  => s_valid_toggle,
        data_out => m_valid_toggle
    );

    -- Synchronizer to convert the read toggle from the M clock domain to the S clock domain.
    read_sync : synchronizer
    generic map (
        reset_value    => '0',
        num_flip_flops => 2
    )
    port map (
        rst      => areset,
        clk      => s_axis_aclk,
        data_in  => m_read_toggle,
        data_out => s_read_toggle
    );

    ----------------------------------------------------------------------------
    ---- S Clock Domain
    ----------------------------------------------------------------------------

    -- Flip-Flop to hold the information that will cross the clock domain.
    s_data_ff_i : process(s_axis_aclk, areset_n)
    begin
        if (areset_n = '0') then
            s_data <= (others => '0');
        elsif (rising_edge(s_axis_aclk)) then
            if (s_ready = '1') then
                s_data <= s_axis_tdata;
            end if;
        end if;
    end process;

    -- State machine to handle control signals in the S clock domain.
    s_state_i : process(s_axis_aclk, areset_n)
        -- Inputs to state machine
        --    s_axis_tvalid
        --    s_read_toggle

        -- Outputs to state machine
        --    s_valid_toggle
        --    s_ready
        variable previous_s_read_toggle : std_logic;
    begin

        if (areset_n = '0') then
            s_valid_toggle         <= '0';
            s_state                <= S_IDLE;
            previous_s_read_toggle := '0';

        elsif (rising_edge(s_axis_aclk)) then
            case s_state is
                -- When idle look for valid axis input, and toggle the valid
                -- line to signal to the M domain state machine.
                when S_IDLE =>
                    if (s_axis_tvalid = '1') then
                        s_state <= S_SEND;
                        s_valid_toggle <= not s_valid_toggle;
                    end if;

                -- When in the send state listen for a read toggle to
                -- acknowledge the send.
                when S_SEND =>
                    if (s_read_toggle /= previous_s_read_toggle) then
                        previous_s_read_toggle := s_read_toggle;
                        s_state <= S_IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- Signals controlled by state of machine
    s_state_out_i : process(s_state, areset_n)
    begin
        if (areset_n = '0') then
            s_ready <= '0';
        else
            case s_state is
                when S_IDLE =>
                    s_ready <= '1';
                when S_SEND =>
                    s_ready <= '0';
            end case;
        end if;
    end process;

    -- Set external s_axis_tready
    s_axis_tready <= s_ready;

    ----------------------------------------------------------------------------
    ---- M Clock Domain
    ----------------------------------------------------------------------------

    -- Generate a read pulse from a toggle on the m_valid_toggle line.
    m_valid_toggle_f_i : process(m_axis_aclk, areset_n)
    begin
        if (areset_n = '0') then
            m_valid_toggle_f <= '0';

        elsif (rising_edge(m_axis_aclk)) then
            m_valid_toggle_f <= m_valid_toggle;
        end if;
    end process;
    m_read_pulse <= m_valid_toggle xor m_valid_toggle_f;

    -- m_axis data is set to the s_data
    -- A pass-through is fine since the valid signal is delayed through
    -- synchronization logic and s_data is constant until acknowledged.
    m_axis_tdata <= s_data;

    -- Valid signal is passed through to reduce cycles needed.
    m_valid <= m_read_pulse or m_valid_l;

    -- Set/clear flip-flop for m_valid signal
    m_valid_ff : process(m_axis_aclk, areset_n)
    begin
        if (areset_n = '0') then
            m_valid_l <= '0';
            m_read_toggle <= '0';

        elsif (rising_edge(m_axis_aclk)) then
            -- Clear valid and toggle read
            -- Clear is given priority over the set
            if (m_axis_tready = '1' and m_valid = '1') then
                m_valid_l <= '0';
                m_read_toggle <= not m_read_toggle;

            -- Set valid
            elsif (m_read_pulse = '1') then
                m_valid_l <= '1';
            end if;

        end if;
    end process;

    -- Set external tvalid
    m_axis_tvalid <= m_valid;

end Behavioral;

-- vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
