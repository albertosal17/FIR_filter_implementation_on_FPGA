

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fir_MA is
  generic (
    DATA_W   : integer := 24;  -- input and output data width
    COEFF_W  : integer := 12;  -- coefficients width
    ACC_W    : integer := 44;  -- accumulator width (24+12 + 6 + 2 guard bits)
    N_TAPS    : integer := 4   -- order of the filter = N_TAPS - 1
  );
  port (
    clock       : in  std_logic; -- clock
    reset       : in  std_logic; -- active LOW reset
    i_data : in  std_logic_vector(DATA_W-1 downto 0); -- input data (signed)
    o_data: out std_logic_vector(DATA_W-1 downto 0)  --  output data (signed, after saturation)
  );
end entity;

architecture rtl of fir_MA is

  ------------
  -- Rappresentazione Q0.12 per i numeri decimali, con 12 bit di parte frazionaria
  -- Nota: poi, dopo l'accumulo, bisogna fare uno shift right di 12 bit (cioè dividere per 2^12) per riportare i risultati alla scala corretta.
  constant FRAC : integer := 12;
  ----------------------------------------------------------------------------------------------------------------------------------------
  -- vettore che contiene i N_TAPS campioni
  type x_arr_t is array (0 to N_TAPS-1) of signed(DATA_W-1 downto 0);
  signal x : x_arr_t := (others => (others => '0'));

  ----------------------------------------------------------------------------------------------------------------------------------------
  -- COEFFICIENTI DEL FILTRO
  -- Coefficiente filtro moving average (uguale per tutti i tap)
  constant A : integer :=  (2**FRAC);
  constant COEFF_VALUE: integer :=  A / N_TAPS; --1/N_TAPS in rappresentazione Q0.12
  constant COEFF      : signed(COEFF_W-1 downto 0) := to_signed(COEFF_VALUE, COEFF_W);

  ----------------------------------------------------------------------------------------------------------------------------------------
  signal acc_scaled : signed(ACC_W-1 downto 0); -- accumulatore con i bit frazionari rimossi (shift right di FRAC bit)

  ----------------------------------------------------------------------------------------------------------------------------------------
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

----------------------------------------------------------------------------------------------------------------------------------------


-- Descrivo il comportamento del filtro
begin

  process(clock) -- 'clock' is word select clock in implementation
    variable acc_v : signed(ACC_W-1 downto 0); --actual value in the accumulator
    variable xin   : signed(DATA_W-1 downto 0); -- actual input signal
    variable prod  : signed(DATA_W + COEFF_W - 1 downto 0);  --actual product between input and the coefficient of the filter 
  
  begin
    if rising_edge(clock) then
      if reset = '0' then -- in caso di reset
        for i in 0 to N_TAPS-1 loop
          x(i) <= (others => '0');
        end loop;
        acc_scaled <= (others => '0');
      
      else
        xin := signed(i_data);

        -- shift register
        for i in N_TAPS-1 downto 1 loop
          x(i) <= x(i-1);
        end loop;
        x(0) <= xin;

        -- accumulo: somma dei prodotti x(i) * COEFF
        acc_v := (others => '0');
        for i in 0 to N_TAPS-1 loop
          prod  := resize(x(i) * COEFF, prod'length); 
          acc_v := acc_v + resize(prod, ACC_W);
        end loop;
      
        acc_scaled <= shift_right(acc_v, FRAC); -- rimuove i bit frazionari

      end if;
    end if;
  end process;

  -- saturo e converto l'uscita in signed 24 bit
  o_data <= std_logic_vector( saturation_signed(acc_scaled) );

end architecture;
