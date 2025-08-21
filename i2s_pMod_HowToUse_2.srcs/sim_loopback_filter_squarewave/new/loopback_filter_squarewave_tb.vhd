-- ============================================================
-- Testbench behavior summary
-- ============================================================
-- Modifica di i2s_loopback_filter_basic_tb.vhd sostituendoo il dizionario
-- di parole da inviare in input con un segnale tipo onda quadra. Il segnale
-- viene filtrato e il risultato esce in output dal transreceiver. I dati dei segnali 
-- in input e output vengono salvati in un .csv che permette di analizzarli 
-- esternamente con uno script di Python
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;
use ieee.std_logic_textio.all;  
use ieee.numeric_std.all;

entity i2s_loopback_filter_squarewave_tb is
end;


architecture tb of i2s_loopback_filter_squarewave_tb is
  -- =========================
  -- Clocks & reset
  -- =========================
  constant MCLK_PERIOD : time := 80 ns;  -- ~12.5 MHz (va bene lo stesso in sim). 
  signal   mclk        : std_logic := '0';
  signal   reset_n     : std_logic := '0';   -- async active-low shared betweeen transceiver and filter

  -- =========================
  -- I2S wires (mastered by DUT)
  -- =========================
  signal sclk   : std_logic;
  signal ws     : std_logic;
  signal sd_rx  : std_logic := '0';  -- TB -> DUT (ingresso seriale)
  signal sd_tx  : std_logic;         -- DUT -> TB (uscita seriale)

  -- =========================
  -- Parallel domain del transceiver 
  -- =========================
  constant D_WIDTH : integer := 24;
  signal l_rx, r_rx : std_logic_vector(D_WIDTH-1 downto 0);
  signal l_tx, r_tx : std_logic_vector(D_WIDTH-1 downto 0);

  -- =========================
  -- FIR domain (8-bit in, 10-bit out) + coeff
  -- =========================
  -- Funzione per troncamento 24->8: prendo i bit [23:16] (MSB-first, two's complement)
  function to_s8(x : std_logic_vector(23 downto 0)) return std_logic_vector is
  begin
    return x(23 downto 16);
  end function;

  -- Funzione per estensione 10->24 con segno
  function sxt10_to_24(x10 : std_logic_vector(9 downto 0)) return std_logic_vector is
    variable sgn  : std_logic := x10(9);
    variable ext  : std_logic_vector(23 downto 0);
  begin
    ext(9 downto 0)   := x10;
    ext(23 downto 10) := (others => sgn);
    return ext;
  end function;

  -- FIR I/O
  signal l_in_8  : std_logic_vector(7 downto 0);
  signal r_in_8  : std_logic_vector(7 downto 0);
  signal l_out_10: std_logic_vector(9 downto 0);
  signal r_out_10: std_logic_vector(9 downto 0);
  -- segnali che processano l'output del filtro per normalizzare il guadagno (per evitare che il segnale saturi/esploda)
  signal l_out_10_sc, r_out_10_sc : std_logic_vector(9 downto 0); 

  ---------
  -- Coefficienti media mobile di 4 campioni (1,1,1,1)
  ---------
  -- constant C0 : std_logic_vector(7 downto 0) := x"01";
  -- constant C1 : std_logic_vector(7 downto 0) := x"01";
  -- constant SHIFT : integer := 2;
  ---------
  -- Coefficienti filtro passa-basso (1,2,2,1)
  ---------
  constant C0 : std_logic_vector(7 downto 0) := x"01";
  constant C1 : std_logic_vector(7 downto 0) := x"02";
  constant SHIFT : integer := 3;
  
  -- =========================
  -- Stimulus 24 bit square wave, on the right channel (left channel left empty for the scope of this sim)
  -- =========================
    -- Square-wave params
    constant AMP_POS      : std_logic_vector(23 downto 0) := x"200000"; -- +amp (24-bit signed)
    constant AMP_NEG      : std_logic_vector(23 downto 0) := x"E00000"; -- -amp
    constant HALF_PERIOD  : integer := 24;  -- with mclk period 80 ns this leads to a approx 1 kHz squarewave (ws frequency is like 48 kHz if you do the math, so the period is 20 us. 24 clock then means 24*20 us = 480 us, for a total period of 480*2 = 960 us, which is around 1 kHz square wave)
    signal   sq_state     : std_logic := '0';
    signal   sq_count     : integer := 0;


  -- Impostazioni su lunghezza segnali campionati/trasferiti, e indice bit campionato
  constant SLOT_BITS : integer := 32;  -- il tuo transceiver usa sclk_ws_ratio=64 => 32 bit per canale tipici I2S
  signal bit_idx  : integer := SLOT_BITS-1;

  -- current words that are sampled (per comodit�)
  signal curL, curR : std_logic_vector(D_WIDTH-1 downto 0) := (others=>'0');

  -- Segnale necessario per clock del FIR left (vedi sotto)
  signal ws_n : std_logic;

  -- Outstream su file .csv
  signal sample_idx : integer := 0;
  file fcsv : text; 

begin
  -- =========================
  -- MCLK generation + reset
  -- =========================
  mclk <= not mclk after MCLK_PERIOD/2;

  process
  begin
    reset_n <= '0';
    wait for 20 * MCLK_PERIOD;
    reset_n <= '1';
    wait;
  end process;

  -- 2) Apertura file all'avvio (dopo il reset)
  open_file: process
  begin
    file_open(fcsv, string'("C:/Users/ASUS/Desktop/TRIOSSI/final_project/i2s_pMod_HowToUse_2/log_simulations/fir_squarewave_sim_logs.csv"), write_mode);
    wait; -- resta aperto per tutta la sim
  end process;
  
  -- =========================
  -- DUT: i2s_transceiver (master RX/TX)
  -- =========================
  dut: entity work.i2s_transceiver
    generic map (
      mclk_sclk_ratio => 4,
      sclk_ws_ratio   => 64,
      d_width         => D_WIDTH
    )
    port map (
      reset     => reset_n,  -- async active-low
      mclk      => mclk,
      sclk      => sclk,     -- out
      ws        => ws,       -- out (LRCK)
      sd_tx     => sd_tx,    -- out
      sd_rx     => sd_rx,    -- in  (nostro stimolo seriale)
      l_data_tx => l_tx,     -- in  (parallelo verso TX)
      r_data_tx => r_tx,     -- in
      l_data_rx => l_rx,     -- out (parallelo da RX)
      r_data_rx => r_rx      -- out
    );

  -- =========================
  -- Serial stimulus on sd_rx (rispetta I2S: WS cambia un sclk prima dell'MSB, dati cambiano sul falling)
  -- =========================
  
  -- Caricamento di L/R correnti dal buffer quando entriamo in Left (ws='0', falling edge)  
-- Ogni inizio canale Left (ws scende 1->0) scegli il prossimo sample
  process(ws)
  begin
    if ws = '0' then
      if sq_count = 0 then
        sq_state <= not sq_state;
        sq_count <= HALF_PERIOD - 1;
      else
        sq_count <= sq_count - 1;
      end if;
      if sq_state = '0' then
        curL <= AMP_POS;
      else
        curL <= AMP_NEG;
      end if;

      -- per il Right puoi tenere 0 o un'altra quadra
      curR <= (others => '0');
    end if;
  end process;

  -- Campionamento della current word
  stim_ser: process(sclk)
    variable w : std_logic_vector(D_WIDTH-1 downto 0);
  begin
    if falling_edge(sclk) then
      -- restart slot counter ogni 32 sclk
      if bit_idx = 0 then
        bit_idx <= SLOT_BITS-1;
      else
        bit_idx <= bit_idx - 1;
      end if;

      -- seleziona la parola per canale attuale
      w := (others=>'0');
      if ws='0' then 
        w := curL; --Left channel
      else 
        w := curR; --Right channel
      end if;

      -- I2S: MSB un clock dopo il toggle WS, e mappiamo i 24 bit della current word dentro lo slot da 32 bit
      if bit_idx <= SLOT_BITS-2 and bit_idx >= (SLOT_BITS - (D_WIDTH)) then
        sd_rx <= w(D_WIDTH - 1 - ((SLOT_BITS-1) - bit_idx));
      else
        sd_rx <= '0';  -- padding per i bit dopo il 25 (fino al 32)
      end if;
    end if;
  end process;

  -- =========================
  -- FIR Wiring (Left/Right)
  -- Clocking: ogni FIR clockato una volta per campione del proprio canale (cio� con clock ws)
  -- =========================
  -- Troncamento 24->8 (perch� il filtro � costruito cos�, con 8 bit input)
  l_in_8 <= to_s8(l_rx);
  r_in_8 <= to_s8(r_rx);

  -- FIR Left
  ws_n <= not ws;  -- clock per filtro left (fronte di salita quando ws va 1->0: inizio slot Left)
  fir_L: entity work.fir_filter_4
    port map (
      i_clk     => ws_n,
      i_rstb    => reset_n,
      i_coeff_0 => C0, i_coeff_1 => C1, i_coeff_2 => C1, i_coeff_3 => C0,  -- [1,1,1,1] o [1,2,2,1]
      i_data    => l_in_8,
      o_data    => l_out_10
    );

  -- FIR Right: clockato da ws (fronte di salita quando ws va 0->1: inizio slot Right)
  fir_R: entity work.fir_filter_4
    port map (
      i_clk     => ws,
      i_rstb    => reset_n,
      i_coeff_0 => C0, i_coeff_1 => C1, i_coeff_2 => C1, i_coeff_3 => C0, -- [1,1,1,1] o [1,2,2,1]
      i_data    => r_in_8,
      o_data    => r_out_10
    );

    -- Applico normalizzazione del segnale per evitare che esploda
    l_out_10_sc <= std_logic_vector( shift_right( signed(l_out_10), SHIFT) );
    r_out_10_sc <= std_logic_vector( shift_right( signed(r_out_10), SHIFT) );
    
    -- Estensione 10->24. Questo segnale sar� poi trasmesso in output dal transreceiver, che lo trametter� serializzato
    l_tx <= sxt10_to_24(l_out_10_sc);
    r_tx <= sxt10_to_24(r_out_10_sc);

  -- =========================
  -- Scrittura log su file .csv
  -- =========================
  log_left: process(ws)
    variable L       : line;
    variable in8_s   : integer;
    variable out10_s : integer;
  begin
    if falling_edge(ws) then  -- inizio slot Left (equivalente al rising di not ws, ma pi� "pulito")
      -- scrivi header solo alla prima riga
      if sample_idx = 0 then
        L := null;
        write(L, string'("sample,in_l_8,out_l_10"));
        writeline(fcsv, L);
      end if;

      -- conversioni (se hai 'U'/'X' i to_integer falliscono: inizializza prima i segnali nel TB)
      in8_s   := to_integer(signed(l_in_8));
      out10_s := to_integer(signed(l_out_10));

      -- scrivi riga
      L := null;
      write(L, sample_idx);
      write(L, string'(","));
      write(L, in8_s);
      write(L, string'(","));
      write(L, out10_s);
      writeline(fcsv, L);

      -- (debug) conferma in console che stai loggando
      report "LOG TICK idx=" & integer'image(sample_idx) severity note;

      sample_idx <= sample_idx + 1;
    end if;
  end process;
  
  -- =========================
  -- Fine simulazione
  -- =========================
  end_sim: process
  begin
    wait for 5 ms;
    file_close(fcsv);        -- <<< forza flush + chiusura
    assert false report "Simulation finished" severity failure;
  end process;

end architecture;
