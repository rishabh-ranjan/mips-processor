library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
entity seven_segment_display is
    Port ( clock_100Mhz : in STD_LOGIC;
           reset : in STD_LOGIC;
           displayed_number: in std_logic_vector (15 downto 0);
           anode_activate : out std_logic_vector (3 downto 0);
           led_out : out std_logic_vector (6 downto 0));
end seven_segment_display;

architecture Behavioral of seven_segment_display is
signal osc: std_logic_vector (27 downto 0);
signal ose: std_logic;
signal LED_BCD: std_logic_vector (3 downto 0);
signal rc: std_logic_vector (19 downto 0);
signal LED_activating_counter: std_logic_vector(1 downto 0);
begin
process(LED_BCD)
begin
    case LED_BCD is
    when "0000" => led_out <= "0000001";
    when "0001" => led_out <= "1001111";
    when "0010" => led_out <= "0010010";
    when "0011" => led_out <= "0000110";
    when "0100" => led_out <= "1001100";
    when "0101" => led_out <= "0100100";
    when "0110" => led_out <= "0100000";
    when "0111" => led_out <= "0001111";
    when "1000" => led_out <= "0000000";
    when "1001" => led_out <= "0000100";
    when "1010" => led_out <= "0000010";
    when "1011" => led_out <= "1100000";
    when "1100" => led_out <= "0110001";
    when "1101" => led_out <= "1000010";
    when "1110" => led_out <= "0110000";
    when "1111" => led_out <= "0111000";
    when others =>
    end case;
end process;
process(clock_100Mhz,reset)
begin
    if(reset='1') then
        rc <= (others => '0');
    elsif(rising_edge(clock_100Mhz)) then
        rc <= rc + 1;
    end if;
end process;
 LED_activating_counter <= rc(19 downto 18);
process(LED_activating_counter)
begin
    case LED_activating_counter is
    when "00" =>
        anode_activate <= "0111";
        LED_BCD <= displayed_number(15 downto 12);
    when "01" =>
        anode_activate <= "1011";
        LED_BCD <= displayed_number(11 downto 8);
    when "10" =>
        anode_activate <= "1101";
        LED_BCD <= displayed_number(7 downto 4);
    when "11" =>
        anode_activate <= "1110";
        LED_BCD <= displayed_number(3 downto 0);
    when others =>
    end case;
end process;
process(clock_100Mhz, reset)
begin
        if(reset='1') then
            osc <= (others => '0');
        elsif(rising_edge(clock_100Mhz)) then
            if(osc>=x"5F5E0FF") then
                osc <= (others => '0');
            else
                osc <= osc + "0000001";
            end if;
        end if;
end process;
ose <= '1' when osc=x"5F5E0FF" else '0';
end Behavioral;