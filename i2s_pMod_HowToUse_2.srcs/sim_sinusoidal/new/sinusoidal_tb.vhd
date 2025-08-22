-- In questa simulazione verifico il comportamento del nuovo filtro fir_filter_4_24bit
-- Inserisco in input un segnale sinusoidale a 1 kHz, con rumore ad alta frequenza a 10 kHz e 15 kHz.
-- Il filtro dovrebbe tagliare il rumore e mantenere la sinusoide.
-- Nota: non serve in questa simulazione tutta la parte di gestione I2S, dato che il filtro è un componente standalone.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;         -- sin, math_pi, round
use ieee.std_logic_textio.all;  -- to write std_logic_vector/signed
use std.env.all; -- for stop()

entity fir_filter_4_24bit_tb is
end;

architecture tb of fir_filter_4_24bit_tb is
  constant DATA_W  : integer := 24;
  constant COEFF_W : integer := 12;
  constant ACC_W   : integer := 41;

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal din   : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
  signal dout  : std_logic_vector(DATA_W-1 downto 0); --:= (others => '0');

  -- parametri segnale
  constant FS       : real := 48820.0;     -- word select clock (~48.82 kHz: coerente con test precedente 'squarewave' in cui mlck period 80 us; inoltre è vicina a quella reale che usiamo, pari a 44.1 kHz)
  constant F_TONE   : real := 500.0;      -- 1 kHz, frequenza onda sinusoidale
  constant F_NOISE1 : real := 10000.0;     -- 10 kHz (high frequency noise, to be cutted by the filter)
  constant F_NOISE2 : real := 15000.0;     -- 15 kHz (high frequency noise, to be cutted by the filter)
  constant AMP_MAIN  : real := 0.13; -- la sinusoide principale sarà al 75% del massimo segnale rappresentabile (chiamato "full scale" o FS)
  constant AMP_NOISE : real := 0.009; -- il rumore aggiunto sarà al 20% del massimo segnale rappresentabile

  constant N_SAMPLES : integer := 500;

  -- derive clock period from FS (1 tick = 1 sample) 
  constant CLK_T_NS_i : integer := integer(1.0e9/FS + 0.5);   -- rounded ns  
  constant CLK_PERIOD : time := CLK_T_NS_i * 1 ns;

  -- for logging input and output 
  file fcsv : text open write_mode is "C:/Users/ASUS/Desktop/TRIOSSI/final_project/i2s_pMod_HowToUse_2/log_simulations/fir_sinusoidal_sim_logs.csv";
  signal sample_idx : integer := 0;

  
  function real_to_s24(x : real) return std_logic_vector is
    -- Funzione helper per convertire un numero reale in signed a 16 bit
    -- Serve per convertire il segnale sinusoidale in ingresso al filtro
    -- La conversione è fatta in modo da mantenere il range [-1.0, 0.99997], che è il range del segnale sinusoidale
    -- originale (matematico) e convertire in signed 16 bit, che è la dimensione del segnale in ingresso al filtro.
    -- Args: 
    --   x: numero reale da convertire

    variable s : integer; -- result
    variable lim : integer := 2**23 - 1; -- massimo valore rappresentabile in signed 16 bit
    variable n  : integer := 2**23; -- (modulo del) minimo valore rappresentabile in signed 16 bit
  
    begin
    -- clamp in [-1.0, 0.99997]
    if x > 0.999969 then
      s := lim;
    elsif x < -1.0 then
      s := -n;

    -- altrimenti scala in [-32768, 32767]
    else
      s := integer(round(x * real(lim)));

    end if;

    return std_logic_vector(to_signed(s, 24));

  end;



  -- DUT
  component fir_filter_4_24bit
    generic ( 
      DATA_W: integer := 24; 
      COEFF_W: integer := 12; 
      ACC_W: integer := 40 );
    port(
      clock: in std_logic; 
      reset: in std_logic;
      i_data: in std_logic_vector(DATA_W-1 downto 0);
      o_data: out std_logic_vector(DATA_W-1 downto 0)
    );
  end component;

begin
  -- clock: 1 tick = 1 campione (comodo per TB: più veloce)
  -- Nota: E' la velocità a cui il filtro campiona il segnale, non centra nulla con la frequenza del segnale
  clk <= not clk after 10 ns; 

  -- reset 
  process
  begin
    rst <= '1';
    wait for 5*CLK_PERIOD;
    rst <= '0';
    wait;
  end process;

  -- istanzia FIR
  dut: fir_filter_4_24bit
    generic map (
      DATA_W=>DATA_W, 
      COEFF_W=>COEFF_W, 
      ACC_W=>ACC_W
      )
    port map (
      clock=>clk, 
      reset=>rst, 
      i_data=>din, 
      o_data=>dout
      );

  -- stimolo + logging
  process(clk)
    variable L : line; -- variabile per scrivere su file CSV
    variable t  : real;
    variable v  : real;
    variable in24_i : integer; -- input value (int) for CSV  
    variable in24_slv: std_logic_vector(DATA_W-1 downto 0); 
    variable out24_i : integer;

  -- Collego il filtro ai segnali di input/output
  begin

    if rising_edge(clk) then
      
      -- In caso di reset
      if rst='1' then --sinchronous reset
        sample_idx <= 0;
        din <= (others => '0');
        --dout <= (others => '0');
      
      -- Se non in reset, genero il segnale sinusoidale, lo invio al filtro e ricavo l'output
      else
        
        
        if sample_idx = 0 then
        -- Write header CSV
        L := null;
        write(L, string'("sample,in_l_24,out_l_24"));
        writeline(fcsv, L);
        sample_idx <= sample_idx + 1;

        elsif sample_idx <= N_SAMPLES then
          -- calcolo il tempo (in secondi) per il campione corrente  
          t := real(sample_idx)/FS;

          -- calcolo il valore della sinusoide principale e del rumore a tale istante (uso funzioni matematiche)
          -- il segnale complessivo è la somma dei tre
          v := AMP_MAIN * sin(2.0*math_pi*F_TONE*t)
            + AMP_NOISE * sin(2.0*math_pi*F_NOISE1*t)
            + AMP_NOISE * sin(2.0*math_pi*F_NOISE2*t);

          -- Il segnale calcolato è in range [-1,0]: lo converto in signed 16 bit, che è la dimensione del segnale in ingresso al filtro,  
          -- e lo collego all'input del filtro
          in24_slv := real_to_s24(v); 
          din <= in24_slv;  -- prepare CSV numbers 
          in24_i := to_integer(signed(in24_slv)); 
          out24_i := to_integer(signed(dout)); -- note: 1+ cycle latency typical for FIR
          

          -- Scrivo log input/output in una riga sul CSV 
          
          L := null;
          write(L, sample_idx); -- sample_idx-1 perché il primo log è l'header
          write(L, string'(","));

          write(L, in24_i);  
          write(L, string'(","));

          write(L, out24_i);
          writeline(fcsv, L);

          report "LOG TICK idx=" & integer'image(sample_idx) severity note;
          sample_idx <= sample_idx + 1;

        

          
        else 
          -- done: stop the simulation 
          report "DONE: wrote " & integer'image(N_SAMPLES) & " samples." severity note; 
          stop(0); 
        
        end if;

      end if;

    end if;

  end process;

end architecture;
