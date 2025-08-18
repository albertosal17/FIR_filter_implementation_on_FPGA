library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------------- COMMENTI GENERALI------------------------------------------------------------------
-- Fir filter che viene applicato sugli ultimi 4 campionamenti del segnale
-- Ogni campionamento del segnale è rappresentato da un valore a 8 bit (numero fra -127 e 128)
-- Anche i pesi che moltiplicano il segnale sono numeri a 8 bit

-- In generale, moltiplicando due numeri a 8 bit al più ottieni un numero a 15 bit
-- Siccome poi sommerai quattro di questi numeri da 15 bit, al più avrai un numero a 17 bit: l'output del filtro
-- Qui si è deciso di troncare l'output tenendo solo i primi 10 bit
--------------------------------------------------------------------------------------------------------------------

--Qui dichiari come si chiamano e che tipo sono gli input e gli output del filtro
entity fir_filter_4 is
port (
  i_clk        : in  std_logic; -- clock
  i_rstb       : in  std_logic; -- reset button
  
  -- coefficient
  -- i pesi che andranno a moltiplicare il segnale in input
  i_coeff_0    : in  std_logic_vector( 7 downto 0);
  i_coeff_1    : in  std_logic_vector( 7 downto 0);
  i_coeff_2    : in  std_logic_vector( 7 downto 0);
  i_coeff_3    : in  std_logic_vector( 7 downto 0);
  
  -- data input
  i_data       : in  std_logic_vector( 7 downto 0);
  
  -- filtered data 
  o_data       : out std_logic_vector( 9 downto 0)); --10 bit length is arbitrary (see the top comment)
  
end fir_filter_4;



-- Qui descrivi come calcolare l'output a partire dall'input
architecture rtl of fir_filter_4 is

-- User defined types, li usiamo per i segnali interni
type t_data_pipe      is array (0 to 3) of signed(7  downto 0); -- i 4 campionamenti del segnale
type t_coeff          is array (0 to 3) of signed(7  downto 0); -- i 4 coefficienti
type t_mult           is array (0 to 3) of signed(15    downto 0); --il risultato della moltiplicazione di segnale per coefficiente
type t_add_st0        is array (0 to 1) of signed(15+1  downto 0); -- il risultato della somma dei 4 prodotti

signal r_coeff              : t_coeff ;
signal p_data               : t_data_pipe;
signal r_mult               : t_mult;
signal r_add_st0            : t_add_st0;
signal r_add_st1            : signed(15+2  downto 0); --?

begin

-- Controllo l'input e mi salvo i valori 
p_input : process (i_rstb,i_clk)
begin
  --in case of resetting put both signal and coefficients to zero
  if(i_rstb='0') then
    p_data       <= (others=>(others=>'0'));
    r_coeff      <= (others=>(others=>'0'));
  
  -- for each rising edge of the clock  
  elsif(rising_edge(i_clk)) then
    -- traslo il segnale 
    p_data      <= signed(i_data) & p_data(0 to p_data'length-2); --concateni gli ultimi 3 campionamenti con un nuovo campionamento (buttando via l'ultimo campionamento)
    
    -- salvo i coefficeinti passati in input (possono essere dinamici!)
    r_coeff(0)  <= signed(i_coeff_0); 
    r_coeff(1)  <= signed(i_coeff_1);
    r_coeff(2)  <= signed(i_coeff_2);
    r_coeff(3)  <= signed(i_coeff_3);
    
  end if;
  
end process p_input;

-- Moltiplico i segnali campionati passati in input per i coefficienti passati in input
p_mult : process (i_rstb,i_clk)
begin
  --in case of resetting 
  if(i_rstb='0') then
    r_mult       <= (others=>(others=>'0'));
    
  elsif(rising_edge(i_clk)) then 
  
    for k in 0 to 3 loop
      r_mult(k)       <= p_data(k) * r_coeff(k);
    end loop;
    
  end if;
  
end process p_mult;

-- Sommo i risultati delle moltiplicazioni
p_add_st0 : process (i_rstb,i_clk)
begin
  
  --in case of resetting 
  if(i_rstb='0') then
    r_add_st0     <= (others=>(others=>'0'));
    
  elsif(rising_edge(i_clk)) then
    for k in 0 to 1 loop 
      -- k=0: somma i prodotti di indice 0 e 1
      -- k=1: somma i prodotti di indice 2 e 3
      r_add_st0(k)     <= resize(r_mult(2*k),17)  + resize(r_mult(2*k+1),17);
    end loop;
    
  end if;
  
end process p_add_st0;



p_add_st1 : process (i_rstb,i_clk)
begin

  if(i_rstb='0') then
    r_add_st1     <= (others=>'0');
    
  elsif(rising_edge(i_clk)) then
    -- sommma le due precedenti somme parziali
    r_add_st1     <= resize(r_add_st0(0),18)  + resize(r_add_st0(1),18);
  end if;
  
end process p_add_st1;


p_output : process (i_rstb,i_clk)
begin

  if(i_rstb='0') then
    o_data     <= (others=>'0');
    
  elsif(rising_edge(i_clk)) then
    o_data     <= std_logic_vector(r_add_st1(17 downto 8)); --tengo solo gli ultimi 10 bit

    -- r_add_st1(17 downto 8): This selects bits 17 down to 8, 
    -- i.e., a 10-bit slice starting from the most significant 
    -- end (left) toward the least significant end (right).
    -- CIOE VENGONO TRONCATE LE CIFRE MENO SIGNIFICATIVE, EFFETTUANDO UNO SHIFT CHE CAUSA UN RESCALING
    --GPT:
    --This is a scaling operation — you're removing the least 
    -- significant 8 bits of precision (often used in fixed-point
    -- arithmetic) and just keeping the high part, to fit into a
    -- smaller output width (10 bits in this case).
  end if;
  
end process p_output;


end rtl;