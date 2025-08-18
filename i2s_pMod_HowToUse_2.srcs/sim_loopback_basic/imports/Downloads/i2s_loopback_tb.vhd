--------------------------------------------------------------------------------
-- Simple I2S loopback smoke test
-- - Drives sd_rx with fixed 24-bit words (Left=0x123456, Right=0xABCDEF)
-- - Respects I2S timing: WS flips one SCLK before MSB; data changes on SCLK falling edge
-- - DUT should echo RX -> TX, so sd_tx shows the same words (after initial pipeline)
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;



entity i2s_loopback_tb is
end i2s_loopback_tb;

architecture Behavioral of i2s_loopback_tb is

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
    
    
    -- DUT ports
    signal clock : std_logic := '0';
    signal reset : std_logic := '1';
    signal mclk  : std_logic_vector(1 downto 0);
    signal sclk  : std_logic_vector(1 downto 0);
    signal ws    : std_logic_vector(1 downto 0);
    signal sd_rx : std_logic := '0';
    signal sd_tx : std_logic;
    
    -- Sim params
    constant CLK_PERIOD  : time    := 10 ns;  -- 100 MHz sys clock
    constant DATA_WIDTH  : integer := 24;
    
    -- Patterns to send (Left/Right)
    constant L_PAT : std_logic_vector(DATA_WIDTH-1 downto 0) := x"123456"; --memo: each exadecimal bit correspond to 4 bit
    constant R_PAT : std_logic_vector(DATA_WIDTH-1 downto 0) := x"ABCDEF";
    
    -- I�S driver state
    signal ws_d     : std_logic := '0';
    signal bit_idx  : integer range 0 to DATA_WIDTH := 0;  
    signal cur_word : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

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
        
    -- Reset & run
    stim_proc: process
    begin
        -- Reset
        -- Prima della simulazione resetto i registri premendo il reset button (che e' active low) per 20 sec
        reset <= '0'; --reset signal
        wait for 200 ns;
        reset <= '1'; --release reset signal
        
        wait; --halts the process forever  
    end process;  
        
    ----------------------------------------------------------------------------
    -- I2S SD driver 
    -- - Change SD on SCLK falling edge
    -- - On each WS edge: insert one-bit delay, then output MSB-first of L/R pattern
    --   * ws(0)='0' => Left; ws(0)='1' => Right
    ----------------------------------------------------------------------------
    i2s_sd_rx_driver : process(sclk(0), reset)
    begin
        if reset = '0' then
            ws_d     <= ws(0);
            bit_idx  <= 0;
            cur_word <= (others => '0');
            sd_rx    <= '0';

        elsif falling_edge(sclk(0)) then
            if ws(0) /= ws_d then -- if WS changed since last SCLK ( /= is the operator for "not equal")
                ws_d    <= ws(0);
                
                if ws(0) = '0' then
                    cur_word <= L_PAT;
                else -- ws(0) = '1'
                    cur_word <= R_PAT;
                end if;
                
                sd_rx   <= '0'; -- hold 0s until next SCLK
                bit_idx <= 0; -- update to first bit                
                
            else -- WS did not change
                if bit_idx < DATA_WIDTH then
                    -- Output MSB first
                    sd_rx   <= cur_word(DATA_WIDTH-1 - bit_idx); --read the word from MSB (index DATA_WIDTH-1) to LSB (index 0)
                    bit_idx <= bit_idx + 1;

                else
                    -- Word done; hold 0s until next WS edge
                    sd_rx <= '0';
                    bit_idx <= bit_idx + 1;

                end if;

            end if;

        end if;

    end process;

end Behavioral;
