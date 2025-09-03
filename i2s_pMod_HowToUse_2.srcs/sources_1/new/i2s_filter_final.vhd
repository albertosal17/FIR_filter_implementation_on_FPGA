-- Here I extend i2s_filter_sinusoidal to final presentation
-- Major aims are: 
--      introducing noise in input to the filter by a switch
--      Showing the varius clocks on LED
--      ? Enable input from microphone (via switch) ?

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------------------


ENTITY i2s_filter_final IS
    GENERIC(
        d_width     :  INTEGER := 24 --data width
        );                    
    PORT(
        clock       :  IN  STD_LOGIC;                     --system clock (100 MHz on Basys board)
        reset_btn     :  IN  STD_LOGIC;                     --active HIGH asynchronous reset
        mclk        :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --master clock
        sclk        :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --serial clock (or bit clock)
        ws          :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --word select (or left-right clock)
        sd_rx       :  IN  STD_LOGIC;                     --serial data in
        sd_tx       :  OUT STD_LOGIC;                   --serial data out
        reset_led   :  OUT STD_LOGIC;
        led_mclk_blink : OUT std_logic;
        led_sclk_blink : OUT std_logic;
        led_ws_blink : OUT std_logic;
        switch_noise : IN std_logic;
        led_noise    : OUT std_logic;
        switch_filter : IN std_logic;
        led_filter    : OUT std_logic
        ); 
END i2s_filter_final;


--------------------------------------------------------------------------------------------


ARCHITECTURE logic OF i2s_filter_final IS

--------------------------------------------------------------------------------------------

    ---------- DICHIARO I SEGNALI ---------------
    SIGNAL reset    :  STD_LOGIC; --segnale da collegare al reset active LOW del transreceiver

    SIGNAL master_clk   :  STD_LOGIC;                             --internal master clock signal
    SIGNAL serial_clk   :  STD_LOGIC := '0';                      --internal serial clock signal
    SIGNAL word_select  :  STD_LOGIC := '0';                      --internal word select signal
    SIGNAL l_data_rx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --left channel data received from I2S Transceiver component
    SIGNAL r_data_rx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --right channel data received from I2S Transceiver component
    SIGNAL l_data_tx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --left channel data to transmit using I2S Transceiver component
    SIGNAL r_data_tx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --right channel data to transmit using I2S Transceiver component
  
--------------------------------------------------------------------------------------------

    --declare PLL to create 11.29 MHz master clock from 100 MHz system clock
    COMPONENT clk_wiz_0
        PORT(
            clk_in1     :  IN STD_LOGIC  := '0';
            clk_out1    :  OUT STD_LOGIC);    -- master clock signal    
    END COMPONENT;
 
--------------------------------------------------------------------------------------------

    --declare I2S Transceiver component
    COMPONENT i2s_transceiver IS
        GENERIC(
            mclk_sclk_ratio :  INTEGER := 4;    --number of mclk periods per sclk period
            sclk_ws_ratio   :  INTEGER := 64;   --number of sclk periods per word select period
            d_width         :  INTEGER := 24);  --data width
        PORT(
            reset     :  IN   STD_LOGIC;                              --asynchronous active low reset
            mclk        :  IN   STD_LOGIC;                              --master clock
            sclk        :  OUT  STD_LOGIC;                              --serial clock (or bit clock)
            ws          :  OUT  STD_LOGIC;                              --word select (or left-right clock)
            sd_tx       :  OUT  STD_LOGIC;                              --serial data transmit
            sd_rx       :  IN   STD_LOGIC;                              --serial data receive
            l_data_tx   :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);   --left channel data to transmit
            r_data_tx   :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);   --right channel data to transmit
            l_data_rx   :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);   --left channel data received
            r_data_rx   :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0));  --right channel data received
    END COMPONENT;

--------------------------------------------------------------------------------------------
-- Declare the 24-bit filter
    component fir_filter_4_24bit is
      generic (
        DATA_W  : integer := 24;
        COEFF_W : integer := 12;
        ACC_W   : integer := 41
      );
      port (
        clock  : in  std_logic;  -- WS clock! 1 tick per campione
        reset  : in  std_logic;  -- active LOW
        i_data : in  std_logic_vector(DATA_W-1 downto 0);
        o_data : out std_logic_vector(DATA_W-1 downto 0)
      );
    end component;
    
-- E dichiaro i segnali associati ai due filtri (L-R) che vado a implementare
    signal l_data_filt : std_logic_vector(d_width-1 downto 0); -- output channel L
    signal r_data_filt : std_logic_vector(d_width-1 downto 0); -- output channel R
    signal ws_n        : std_logic;  -- WS invertito per avere il fronte corretto su L 
    
--------------------------------------------------------------------------------------------

 component ila_2
 port (
   clk    : IN std_logic;       
   probe0 : IN std_logic_vector; --r_data_tx
   probe1 : IN std_logic_vector;  --l_data_tx
   probe2 : IN std_logic_vector;  --l_data_rx
   probe3 : IN std_logic_vector;  --l_data_rx
   probe4 : IN std_logic);  --sample_ok
 end component;

--------------------------------------------------------------------------------------------

-- Needed for make blinking led with clocks, to see if they're alive
constant DIV_BIT : integer := 20;

signal div_cnt_mclk   : unsigned(DIV_BIT downto 0) := (others=>'0'); -- 2^24
signal div_cnt_sclk   : unsigned(DIV_BIT downto 0) := (others=>'0'); -- 2^24
signal div_cnt_ws   : unsigned(DIV_BIT downto 0) := (others=>'0'); -- 2^24

--------------------------------------------------------------------------------------------
  -- Strobe signal for the ILA (to capture only on rising edge of ws)
  signal ws_d, sample_ok : std_logic := '0';

--------------------------------------------------------------------------------------------
  -- Noise generator

    component dds_compiler_0
      port (
          aclk          : in  std_logic;
          m_axis_data_tdata   : out std_logic_vector(23 downto 0)
      );
    end component;
    
    signal noise : std_logic_vector(23 downto 0); -- change "Spurious Free Dynamic Range (dB)" field in IP to change output width
    
    signal l_in, r_in : std_logic_vector(d_width-1 downto 0); -- need new input signal definition because of the two cases (noise or no noise)

--------------------------------------------------------------------------------------------
  -- filter bypass
  signal l_to_tx, r_to_tx : std_logic_vector(d_width-1 downto 0);

--------------------------------------------------------------------------------------------

BEGIN

    --------------------------------------------------------------------------------------------

    --instantiate PLL to create master clock
    i2s_clock: clk_wiz_0 
    PORT MAP(
        clk_in1 => clock, 
        clk_out1 => master_clk
        );

    --------------------------------------------------------------------------------------------

    --instantiate I2S Transceiver component    
    reset <= not reset_btn;
    i2s_transceiver_0: i2s_transceiver
        GENERIC MAP(
            mclk_sclk_ratio => 4, 
            sclk_ws_ratio => 64, 
            d_width => d_width
            )
        PORT MAP(
            reset => reset, 
            mclk => master_clk, 
            sclk => serial_clk, 
            ws => word_select, 
            sd_tx => sd_tx, 
            sd_rx => sd_rx,
            l_data_tx => l_data_tx, 
            r_data_tx => r_data_tx, 
            l_data_rx => l_data_rx, 
            r_data_rx => r_data_rx
            );

    --------------------------------------------------------------------------------------------
    
    -- INIZIALIZZO I SEGNALI DI CLOCK
    mclk(0) <= master_clk;  --input master clock to ADC
    mclk(1) <= master_clk;  --input master clock to DAC

    sclk(0) <= serial_clk;  --output serial clock (from I2S Transceiver) to ADC
    sclk(1) <= serial_clk;  --output serial clock (from I2S Transceiver) to DAC

    ws(0) <= word_select;   --output word select (from I2S Transceiver) to ADC
    ws(1) <= word_select;   --output word select (from I2S Transceiver) to DAC

   --------------------------------------------------------------------------------------------
    -- Instanzio i filtri e determino segnali output
    ws_n <= not word_select;
    
    -- Filtro LEFT: clock sul fronte di discesa di WS (rising di ws_n)
    fir_L: fir_filter_4_24bit
      generic map (
        DATA_W  => d_width,
        COEFF_W => 12,
        ACC_W   => 41
      )
      port map (
        clock  => ws_n,         -- rising_edge(ws_n) coincide con falling_edge(WS)
        reset  => reset,        -- active LOW (gi� gestito a monte)
        i_data => l_in,
        o_data => l_data_filt
      );
    
    -- Filtro RIGHT: clock sul fronte di salita di WS
    fir_R: fir_filter_4_24bit
      generic map (
        DATA_W  => d_width,
        COEFF_W => 12,
        ACC_W   => 41
      )
      port map (
        clock  => word_select,  -- rising_edge(WS)
        reset  => reset,
        i_data => r_in,
        o_data => r_data_filt
      );

    ---------------------------------------------------------------------------------------------
    -- FILTER BYPASS IF SWITCH 
    with switch_filter select
      l_to_tx <= l_in         when '0',    --playback case
                 l_data_filt  when '1'; 

    with switch_filter select
      r_to_tx <= r_in         when '0',    --playback case
                 r_data_filt  when '1';

    l_data_tx <= l_to_tx;
    r_data_tx <= r_to_tx;

    led_filter <= switch_filter; -- light if filter is active
    --------------------------------------------------------------------------------------------

    --TO see reset in a led
    reset_led <= reset;

    --------------------------------------------------------------------------------------------

    -- Ila instantiation   
    ila_inst: ila_2
    port map (
     clk    => master_clk,        
     probe0 => l_in,
     probe1 => l_data_tx,
     probe2 => r_in,
     probe3 => r_data_tx,
     probe4 => sample_ok
    );

    -----------------------------------------------------------------------------------------
    -- Check if clock is alive by blinking a led

    --MCLK
    process(master_clk)
    begin
    if rising_edge(master_clk) then
        div_cnt_mclk <= div_cnt_mclk + 1;
    end if;
    end process;
    led_mclk_blink <= std_logic(div_cnt_mclk(DIV_BIT));  -- lampeggia piano se master_clk funziona

    -- SCLK
    process(serial_clk)
    begin
      if rising_edge(serial_clk) then
        div_cnt_sclk <= div_cnt_sclk + 1;
      end if;
    end process;
    led_sclk_blink <= std_logic(div_cnt_sclk(DIV_BIT));


    -- WS
    process(word_select)
    begin
      if rising_edge(word_select) then
        div_cnt_ws <= div_cnt_ws + 1;
      end if;
    end process;
    led_ws_blink <= std_logic(div_cnt_ws(DIV_BIT));
    
    ---------------------------------------------------------------------------------------------

    process(master_clk)
    begin
      if rising_edge(master_clk) then
        ws_d <= word_select;
        if (word_select /= ws_d) then
            sample_ok <= '1'; --sample only when ws toggles
        else 
            sample_ok <='0';
        end if;
      end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- noise generator
    dds_inst: dds_compiler_0
      port map (
          aclk  => master_clk,
          m_axis_data_tdata => noise
      );
      
      with switch_noise select
          l_in <= std_logic_vector( signed(l_data_rx) + signed(noise) ) when '1',  --add noise
                  l_data_rx                                             when '0';
        
        with switch_noise select
          r_in <= std_logic_vector( signed(r_data_rx) + signed(noise) ) when '1',  --add noise
                  r_data_rx                                             when '0';

    led_noise <= switch_noise; -- light if noise is added to input
    ---------------------------------------------------------------------------------------------

END logic;



