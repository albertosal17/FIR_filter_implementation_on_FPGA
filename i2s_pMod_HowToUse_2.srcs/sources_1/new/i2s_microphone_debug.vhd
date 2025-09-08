-- Questo file contiene il codice di base per implementare il transreceiver in funzione 
-- playback: quello che entra, esce (a.k.a. senza filtraggio del segnale)


LIBRARY ieee;
USE ieee.std_logic_1164.all;



ENTITY i2s_microphone_debug IS
    GENERIC(
        d_width     :  INTEGER := 24 --data width
        );                    
    PORT(
        clock       :  IN  STD_LOGIC;                     --system clock (100 MHz on Basys board)
        reset_btn     :  IN  STD_LOGIC;                     --active low asynchronous reset
        mclk        :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --master clock
        sclk        :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --serial clock (or bit clock)
        ws          :  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  --word select (or left-right clock)
        sd_rx       :  IN  STD_LOGIC;                     --serial data in
        sd_tx       :  OUT STD_LOGIC;
        channel_mic :  OUT STD_LOGIC                           --serial data out
        ); 
END i2s_microphone_debug;



ARCHITECTURE logic OF i2s_microphone_debug IS

    ---------- DICHIARO I SEGNALI ---------------
    SIGNAL master_clk   :  STD_LOGIC;                             --internal master clock signal
    SIGNAL serial_clk   :  STD_LOGIC := '0';                      --internal serial clock signal
    SIGNAL word_select  :  STD_LOGIC := '0';                      --internal word select signal
    SIGNAL l_data_rx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --left channel data received from I2S Transceiver component
    SIGNAL r_data_rx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --right channel data received from I2S Transceiver component
    SIGNAL l_data_tx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --left channel data to transmit using I2S Transceiver component
    SIGNAL r_data_tx    :  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --right channel data to transmit using I2S Transceiver component

    SIGNAL reset    :  STD_LOGIC; --segnale da collegare al reset active LOW del transreceiver
    ---------- DICHIARO LE COMPONENTI ---------------
    --declare PLL to create 11.29 MHz master clock from 100 MHz system clock
    COMPONENT clk_wiz_0
        PORT(
            clk_in1     :  IN STD_LOGIC  := '0';
            clk_out1    :  OUT STD_LOGIC);    -- master clock signal    
    END COMPONENT;

    
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
    
    
    
     component ila_3
     port (
       clk    : IN std_logic;       
       probe0 : OUT std_logic; 
       probe1 : OUT std_logic;  
       probe2 : OUT std_logic;  
       probe3 : IN std_logic;  
       probe4 : IN std_logic_vector(23 downto 0);  
       probe5 : IN std_logic_vector(23 downto 0);  
       probe6 : OUT std_logic_vector(23 downto 0); 
       probe7 : OUT std_logic_vector(23 downto 0));        
     end component;

     
-- INIZIALIZZO SEGNALI E COMPONENTI --
BEGIN

    reset <= not reset_btn;

    --instantiate PLL to create master clock
    i2s_clock: clk_wiz_0 
    PORT MAP(
        clk_in1 => clock, 
        clk_out1 => master_clk
        );
  
    --instantiate I2S Transceiver component
    i2s_transceiver_0: i2s_transceiver
        GENERIC MAP(
            mclk_sclk_ratio => 4, 
            sclk_ws_ratio => 64, 
            d_width => 24
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
      
    ---------- INIZIALIZZO I SEGNALI DI INPUT/OUTPUT ---------------
    mclk(0) <= master_clk;  --output master clock to ADC
    mclk(1) <= master_clk;  --output master clock to DAC

    sclk(0) <= serial_clk;  --output serial clock (from I2S Transceiver) to ADC
    sclk(1) <= serial_clk;  --output serial clock (from I2S Transceiver) to DAC

    ws(0) <= word_select;   --output word select (from I2S Transceiver) to ADC
    ws(1) <= word_select;   --output word select (from I2S Transceiver) to DAC
    
    -- playback: quello che entra esce
    r_data_tx <= r_data_rx;  --assign right channel received data to transmit (to playback out received data)
    l_data_tx <= l_data_rx;  --assign left channel received data to transmit (to playback out received data)

    -- Ila instantiation   
    ila_inst: ila_3
    port map (
     clk    => master_clk,     
     probe0 => serial_clk,   
     probe1 => word_select,
     probe2 => sd_tx,
     probe3 => sd_rx,
     probe4 => l_data_tx,
     probe5 => r_data_tx,
     probe6 => l_data_rx,
     probe7 => r_data_rx
    );
    
    channel_mic <= '0';
END logic;
