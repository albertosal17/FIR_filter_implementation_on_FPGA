----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.08.2025 15:10:13
-- Design Name: 
-- Module Name: clk_wiz0 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity clk_wiz_0 is
  Port ( 
    clk_in1 : in STD_LOGIC;  -- Input clock signal (100 MHz simulated clock)
    clk_out1 : out STD_LOGIC  -- Output clock signal (master clock)
  );
end clk_wiz_0;

architecture Behavioral of clk_wiz_0 is
    -- Divide 100 MHz by 8 → 12.5 MHz (close enough to 11.2896 for functional sim)ù
    signal div : integer range 0 to 3 := 0;  -- Divided clock signal
    signal r       : STD_LOGIC := '0';  -- Output clock signal
begin
    process(clk_in1)
    begin
        if rising_edge(clk_in1) THEN
            if div = 3 THEN
                div <= 0;
                r <= NOT r;  -- Toggle the output clock every 4 input clock cycles
            else
                div <= div + 1;  -- Increment the divider
            end if;
        end if;
    end process;

    clk_out1 <= r;  -- Assign the divided clock to the output

end Behavioral;
