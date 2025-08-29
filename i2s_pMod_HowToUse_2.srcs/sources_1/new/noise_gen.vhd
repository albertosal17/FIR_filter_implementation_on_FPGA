-- This entity generates a sinusoidal signal at high frequency (10 kHz)
-- It can be used to inject noise in a given signal, expecially to
-- see the effects of a low-pass filter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tone_gen_10k is
  generic (
    DATA_W      : integer := 24;  -- ampiezza uscita
    PHASE_W     : integer := 32;  -- accumulatore di fase
    LUT_BITS    : integer := 6;   -- 64 campioni
    NOISE_SHIFT : integer := 2    -- attenuazione: /2^NOISE_SHIFT (2 -> ~ -12 dB)
  );
  port (
    clk         : in  std_logic;  -- clock di dominio (stesso di sample_ok)
    reset_n     : in  std_logic;  -- reset attivo basso
    sample_tick : in  std_logic;  -- 1 ciclo per NUOVO campione (usa sample_ok)
    tone_out    : out std_logic_vector(DATA_W-1 downto 0)
  );
end entity;



architecture rtl of tone_gen_10k is
  -- Fs ? 44.1 kHz. Per f ? 10 kHz: phase_inc = round(2^32 * f / Fs) = 973,915,487 = x"3A0CC55F"
  constant PHASE_INC : unsigned(PHASE_W-1 downto 0) := to_unsigned(973915487, PHASE_W);

  signal phase_acc : unsigned(PHASE_W-1 downto 0) := (others=>'0');

  type lut_t is array (0 to (2**LUT_BITS)-1) of std_logic_vector(DATA_W-1 downto 0);
  -- Sine LUT 64 campioni, 24-bit signed full-scale (due's complement)
  constant SINE_LUT : lut_t := (
    x"000000", x"0C8BD3", x"18F8B8", x"25280C", x"30FBC5", x"3C56BA", x"471CEB", x"5133CC",
    x"5A8279", x"62F201", x"6A6D98", x"70E2CB", x"7641AF", x"7A7D05", x"7D8A5F", x"7F6236",
    x"7FFFFF", x"7F6236", x"7D8A5F", x"7A7D05", x"7641AF", x"70E2CB", x"6A6D98", x"62F201",
    x"5A8279", x"5133CC", x"471CEB", x"3C56BA", x"30FBC5", x"25280C", x"18F8B8", x"0C8BD3",
    x"000000", x"F3742D", x"E70748", x"DAD7F4", x"CF043B", x"C3A945", x"B8E315", x"AECB34",
    x"A57D87", x"9D0DFF", x"959267", x"8F1D34", x"89BE50", x"8582FA", x"8275A1", x"819DCA",
    x"800001", x"819DCA", x"8275A1", x"8582FA", x"89BE50", x"8F1D34", x"959267", x"9D0DFF",
    x"A57D87", x"AECB34", x"B8E315", x"C3A945", x"CF043B", x"DAD7F4", x"E70748", x"F3742D"
  );

  signal lut_word   : std_logic_vector(DATA_W-1 downto 0);
  signal tone_s     : signed(DATA_W-1 downto 0);
  signal tone_atten : signed(DATA_W-1 downto 0);
begin
  -- Avanza di un passo per ogni NUOVO campione (tick)
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        phase_acc <= (others=>'0');
      elsif sample_tick = '1' then
        phase_acc <= phase_acc + PHASE_INC;
      end if;
    end if;
  end process;

  -- Indice = MSB della fase (primi LUT_BITS)
  lut_word <= SINE_LUT(to_integer(phase_acc(PHASE_W-1 downto PHASE_W-LUT_BITS)));

  -- Attenua /2^NOISE_SHIFT per headroom
  tone_s     <= signed(lut_word);
  tone_atten <= shift_right(tone_s, NOISE_SHIFT);

  tone_out <= std_logic_vector(tone_atten);
end architecture;
