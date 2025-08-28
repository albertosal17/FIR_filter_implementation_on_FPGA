-- THIS FILE CONTAINS THE IMPLEMENTATION OF THE FIR FILTER BASED ON fir_filter_4.vhd WITH
-- THE EXTENSION OG DATA WITDTH TO 24 BIT FOR IMPLEMENTATION PURPOSES (THE PMOD READS 24 BIT DATA)
-- OTHER MINOR MODIFICATIONS TO THE ARCHITECTURE HAVE BEEN MADE, IN PARTICULAR: 
-- NO DYNAMIC COEFFICIENTS BUT A FIXEDLOW-PASS FILTER
-- NORMAZILED GUADAGNO: OUTPUT SIGNAL HAS SAME MAGNITUDE OF THE INPUT ONE
-- SATURATION STRATEGY FOR SIGNALS WHO UNDER/OVER-FIT

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir_filter_4_24bit is
  generic (
    DATA_W   : integer := 24;                  -- ampiezza (in bit) dei dati in ingresso e uscita
    COEFF_W  : integer := 12;                  -- ampiezza (in bit) dei coefficienti
    ACC_W    : integer := 41                   -- ampiezza accumulatore (24+12+2 (somma 4 tap) + 3 guard bits)
  );
  port (
    clock       : in  std_logic; -- clock
    reset       : in  std_logic; -- active LOW reset
    i_data : in  std_logic_vector(DATA_W-1 downto 0); -- input data (signed)
    o_data: out std_logic_vector(DATA_W-1 downto 0)  --  output data (signed, after saturation)
  );
end entity;

architecture rtl of fir_filter_4_24bit is
  -- Coefficienti interi [1,2,2,1] per filtro passa-basso
  -- In questo caso li tengo costanti, e non dinamici come in fir_filter_4.vhd
  ------------
  -- USA QUESTI NEL CASO DI GUADAGNO NON UNITARIO (guadagno=6: 1+2+2+1)
  --constant C0 : signed(COEFF_W-1 downto 0) := to_signed(1, COEFF_W);
  --constant C1 : signed(COEFF_W-1 downto 0) := to_signed(2, COEFF_W);
  --constant C2 : signed(COEFF_W-1 downto 0) := to_signed(2, COEFF_W);
  --constant C3 : signed(COEFF_W-1 downto 0) := to_signed(1, COEFF_W);
  ------------
  -- USA QUESTI NEL CASO DI GUADAGNO UNITARIO (guadagno=1: 1/6)
  -- rappresentazione Q0.12 per i numeri decimali, con 12 bit di parte frazionaria
  -- Nota: poi, dopo l’accumulo, bisogna fare uno shift right di 12 bit (cioè dividere per 2^12) per riportare i risultati alla scala corretta.
  constant FRAC : integer := 12;
  constant C0 : signed(COEFF_W-1 downto 0) := to_signed( 683, COEFF_W);  -- 1/6 (1/6=0.16 -> 0.16* 2^12 = 0.16 * 4096 ≈ 683)
  constant C1 : signed(COEFF_W-1 downto 0) :=  to_signed(1365, COEFF_W);  -- 2/6
  constant C2 : signed(COEFF_W-1 downto 0) := C1;
  constant C3 : signed(COEFF_W-1 downto 0) := C0;
  ------------


  signal x0, x1, x2, x3 : signed(DATA_W-1 downto 0); -- shift register per i 4 campioni del segnale in ingresso
  signal xin            : signed(DATA_W-1 downto 0); -- segnale in ingresso (convertito in signed)

  -- prodotti e somma su ampiezza estesa
  signal p0, p1, p2, p3 : signed((DATA_W + COEFF_W)- 1 downto 0); -- prodotti tra segnale e coefficienti. Memo: when you multiply two numbers of N-bit and M-bit the output of the multiplication result is (N+M)-bits.
  signal acc            : signed(ACC_W-1 downto 0); -- accumulatore per i prodotti, con ampiezza estesa
  signal acc_scaled : signed(ACC_W-1 downto 0); -- accumulatore con ampiezza estesa, ma con i bit frazionari rimossi (shift right di FRAC bit)

  -- uscita estesa (senza normalizzazione: guadagno max = somma coeff = 6)
  signal y_ext          : signed(ACC_W-1 downto 0);


  -- funzione di saturazione verso DATA_W bit
  function saturation_signed(inp : signed) return signed is
    -- Questa funzione prende un segnale signed di ampiezza arbitraria e lo satura a DATA_W bit
    -- Se il valore supera il massimo o il minimo rappresentabile, lo satura al massimo
    -- o al minimo rappresentabile, altrimenti lo ridimensiona a DATA_W bit, troncando i bit in eccesso (mantenendo i most significant bit)
    
    variable res : signed(DATA_W-1 downto 0); -- risultato della saturazione
    variable maxv : signed(DATA_W-1 downto 0) := to_signed(2**(DATA_W-1)-1, DATA_W); -- massimo valore rappresentabile
    variable minv : signed(DATA_W-1 downto 0) := to_signed(-2**(DATA_W-1), DATA_W); -- minimo valore rappresentabile
  
  begin

    -- Controllo se il valore in ingresso supera i limiti, e nel caso lo satura
    if inp > resize(maxv, inp'length) then 
      res := maxv;
    elsif inp < resize(minv, inp'length) then
      res := minv;

    -- Altrimenti lo ridimensiono a DATA_W bit
    else
      res := resize(inp, DATA_W);
    
    end if;

    return res;

  end function;



-- Descrivo il comportamento del filtro
begin
  xin <= signed(i_data);

  process(clock) -- word select clock in implementation
  begin
    if rising_edge(clock) then
      if reset = '0' then -- in caso di reset
        x0 <= (others=>'0'); x1 <= (others=>'0'); x2 <= (others=>'0'); x3 <= (others=>'0');
        acc <= (others=>'0');
      
      else
        -- shift register
        x3 <= x2;
        x2 <= x1;
        x1 <= x0;
        x0 <= xin;

        -- prodotti
        -- resize dei fattori così vivado capisce che il risultato sarà di ampiezza (DATA_W + COEFF_W) bit
        p0 <= resize( signed(x0) * signed(C0), (DATA_W + COEFF_W) );
        p1 <= resize( signed(x1) * signed(C1), (DATA_W + COEFF_W) );
        p2 <= resize( signed(x2) * signed(C2), (DATA_W + COEFF_W) );
        p3 <= resize( signed(x3) * signed(C3), (DATA_W + COEFF_W) );

        -- accumulo: sommo i prodotti
        -- resize per evitare overflow, e somma con saturazione
        acc <= resize(p0, ACC_W) + resize(p1, ACC_W) + resize(p2, ACC_W) + resize(p3, ACC_W);

        acc_scaled <= shift_right(acc, FRAC); -- rimuove i bit frazionari
        -- ATTENZIONE: usa solo nel caso in cui usi guadagno unitario (guadagno=1: 1/6), altrimenti non serve

      end if;
    end if;
  end process;

  -- saturiamo e convertiamo l'uscita in signed 16 bit
  o_data <= std_logic_vector(saturation_signed(acc_scaled));

end architecture;
