-- EXTREMELY BASIC TESTBENCH TO LOOK IF EVERYTHING WORKS CORRECTLY 
-- WITH THE VARIOUS CLOCKS


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity pMod_tb is
end pMod_tb;

architecture Behavioral of pMod_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component i2s_playback
        generic (
            d_width : integer := 24
        );
        port (
            clock : in std_logic;
            reset : in std_logic;
            mclk : out std_logic_vector(1 downto 0);
            sclk : out std_logic_vector(1 downto 0);
            ws : out std_logic_vector(1 downto 0);
            sd_rx : in std_logic;
            sd_tx : out std_logic
        );
    end component;

    -- Signals for the UUT
    -- Input signals
    signal clock : std_logic := '0';
    signal reset : std_logic := '1';
    signal sd_rx : std_logic := '0'; -- Assuming no data is received initially
    -- Output signals
    signal mclk : std_logic_vector(1 downto 0);
    signal sclk : std_logic_vector(1 downto 0);
    signal ws : std_logic_vector(1 downto 0);
    signal sd_tx : std_logic;

    -- Parameters for the stimulus
    constant clk_period : time := 10 ns; -- Clock period of 10 ns (for 100 MHz)
    constant DATA_WIDTH : integer := 24;
    
    -- checker for WS toggle
    signal ws_prev: std_logic := '0';
    signal sclk_count: integer := 0;

    
begin

    -- Clock generation process
    clk_process : process
    begin
        while true loop
            clock <= '0';
            wait for clk_period / 2;
            clock <= '1';
            wait for clk_period / 2;
        end loop;
    end process;




    -- Instantiate the Unit Under Test (UUT)
    -- Devo associare i segnali della simulazione con l'entity i2s_playback
    uut: i2s_playback
        generic map (
            d_width => DATA_WIDTH  -- Set the data width to 24 bits
        )
        port map (
           clock => clock,
           reset => reset,
           mclk => mclk,
           sclk => sclk,
           ws => ws,
           sd_rx => sd_rx,
           sd_tx => sd_tx
        );

        
    -- Stimulus process
    stim_proc: process
    begin
        -- Reset
        -- Prima della simulazione resetto i registri premendo il reset button (che e' active low) per 20 sec
        reset <= '0'; --reset signal
        wait for 200 ns;
        reset <= '1'; --release reset signal
        
        wait; --halts the process forever

    end process;
    
    
    -- Count sclk(0) rising edges between WS toggles and assert correctness
    ws_toggle_checker : process(sclk(0), reset)
    begin
        if reset = '0' then
            ws_prev    <= ws(0);
            sclk_count <= 0;
        elsif falling_edge(sclk(0)) then
            if ws(0) = ws_prev then
                sclk_count <= sclk_count + 1;
            else
                -- Prepare for the next interval
                ws_prev    <= ws(0);
                sclk_count <= 1;  -- count this SCLK as the first of the next interval
            end if;
        end if;
    end process;
    
end Behavioral;
