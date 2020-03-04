library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processor is
port (
    clk: in std_logic;
    switch: in std_logic;
    an: out std_logic_vector(3 downto 0);
    seg: out std_logic_vector(6 downto 0)
);
end processor;

architecture behavioral of processor is
    type state_t is (
        start,
        init1,
        init2,
        branch_delay,
        exec,
        lw_delay,
        lw_final,
        sw_final,
        done
    );
    signal state: state_t := start;
    
    constant reg_count: integer := 32;
    type reg_t is array(0 to reg_count-1) of std_logic_vector(31 downto 0);
    signal reg: reg_t := (
        0 => x"00000000",
        1 => x"00000000",
        2 => x"00000000",
        3 => x"00000000",
        4 => x"00000005",
        8 => x"00000008",
        9 => x"ffffffff",
        10 => x"00000001",
        29 => x"00001000",  -- sp
        others => x"00000000"
    );
    
    signal pc: integer := 0;
    signal opcode: std_logic_vector(5 downto 0);
    signal rr: integer := 0;
    signal rs: integer;
    signal rt: integer;
    signal rd: integer;
    signal shamt: integer;
    signal func: std_logic_vector(5 downto 0);
    signal imm: integer;
    signal target: integer;
        
    signal addra: std_logic_vector(11 downto 0);
    signal dina: std_logic_vector(31 downto 0);
    signal douta: std_logic_vector(31 downto 0);
    signal web: std_logic_vector(0 downto 0) := "0";
    signal addrb: std_logic_vector(11 downto 0);
    signal dinb: std_logic_vector(31 downto 0);
    signal doutb: std_logic_vector(31 downto 0);

    signal rt_tmp: integer;
    signal addr_tmp: std_logic_vector(11 downto 0);

    signal display: std_logic_vector(15 downto 0);
    signal cycle: integer := 1;
    
    component blk_mem_gen_0 is
    port (
        clka: in std_logic;
        ena: in std_logic;
        wea: in std_logic_vector(0 downto 0);
        addra: in std_logic_vector(11 downto 0);
        dina: in std_logic_vector(31 downto 0);
        douta: out std_logic_vector(31 downto 0);
        clkb: in std_logic;
        enb: in std_logic;
        web: in std_logic_vector(0 downto 0);
        addrb: in std_logic_vector(11 downto 0);
        dinb: in std_logic_vector(31 downto 0);
        doutb: out std_logic_vector(31 downto 0)
    );
    end component;
    
begin

    memorypro: blk_mem_gen_0
    port map (
        clka => clk,
        ena => '1',
        wea => "0",
        addra => addra,
        dina => dina,
        douta => douta,
        clkb => clk,
        enb => '1',
        web => web,
        addrb => addrb,
        dinb => dinb,
        doutb => doutb
    );

    sevenpro: entity work.seven_segment_display(Behavioral)
    port map (
        clock_100Mhz => clk,
        reset => '0',
        displayed_number => display,
        anode_activate => an,
        led_out => seg
    );

    display <= reg(rr)(15 downto 0) when switch = '1' else std_logic_vector(to_unsigned(cycle, 16)) when switch = '0';

    opcode <= douta(31 downto 26);
    rs <= to_integer(unsigned(douta(25 downto 21)));
    rt <= to_integer(unsigned(douta(20 downto 16)));
    rd <= to_integer(unsigned(douta(15 downto 11)));
    shamt <= to_integer(unsigned(douta(10 downto 6)));
    func <= douta(5 downto 0);
    imm <= to_integer(signed(douta(15 downto 0)));
    target <= to_integer(signed(douta(25 downto 0)));
        
    process(clk)
    begin
        if rising_edge(clk) then
            cycle <= cycle + 1;
            case state is
            when start =>
                state <= init1;
            when init1 =>
                addra <= std_logic_vector(to_unsigned(pc/4, 12));
                state <= init2;
            when init2 =>
                addra <= std_logic_vector(to_unsigned(pc/4 + 1, 12));
                pc <= pc + 4;
                state <= exec;
            when branch_delay =>
                addra <= std_logic_vector(to_unsigned(pc/4 + 1, 12));
                pc <= pc + 4;
                state <= exec;
            when exec =>
                -- for instr #0, pc = 4
                addra <= std_logic_vector(to_unsigned(pc/4 + 1, 12));
                pc <= pc + 4;
                case opcode is
                when "000000" =>
                    case func is
                    when "100000" =>    -- add
                        reg(rd) <= std_logic_vector(to_signed(to_integer(signed(reg(rs))) + to_integer(signed(reg(rt))), 32));
                        rr <= rd;
                    when "100010" =>    -- sub
                        reg(rd) <= std_logic_vector(to_signed(to_integer(signed(reg(rs))) - to_integer(signed(reg(rt))), 32));
                        rr <= rd;
                    when "000000" =>    -- sll
                        if rs = 0 and rt = 0 and rd = 0 and shamt = 0 then
                            state <= done;
                        else
                            reg(rd) <= std_logic_vector(shift_left(unsigned(reg(rt)), shamt));
                            rr <= rd;
                        end if;
                    when "000010" =>    -- srl
                        reg(rd) <= std_logic_vector(shift_right(unsigned(reg(rt)), shamt));
                        rr <= rd;
                    when "001000" =>    -- jr
                        pc <= to_integer(signed(reg(rs)));
                        addra <= std_logic_vector(shift_right(unsigned(reg(rs)(11 downto 0)), 2));
                        rr <= rs;
                        state <= branch_delay;
                    when others =>
                    end case;
                when "100011" =>    -- lw
                    pc <= pc;
                    rt_tmp <= rt;
                    addrb <= std_logic_vector(to_unsigned(to_integer(unsigned(reg(rs)))/4 + imm/4, 12));
                    state <= lw_delay;
                when "101011" =>    -- sw
                    pc <= pc;
                    addra <= std_logic_vector(to_unsigned(pc/4, 12));
                    addrb <= std_logic_vector(to_unsigned(to_integer(unsigned(reg(rs)))/4 + imm/4, 12));
                    dinb <= reg(rt);
                    rr <= rt;
                    web <= "1";
                    state <= sw_final;
                when "000101" =>    -- bne
                    if reg(rs) /= reg(rt) then
                        pc <= pc + imm*4;
                        addra <= std_logic_vector(to_unsigned(pc/4 + imm, 12));
                        state <= branch_delay;
                    end if;
                when "000100" =>    -- beq
                    if reg(rs) = reg(rt) then
                        pc <= pc + imm*4;
                        addra <= std_logic_vector(to_unsigned(pc/4 + imm, 12));
                        state <= branch_delay;
                    end if;
                when "000110" =>    -- blez
                    if to_integer(signed(reg(rs))) <= 0 then
                        pc <= pc + imm*4;
                        addra <= std_logic_vector(to_unsigned(pc/4 + imm, 12));
                        state <= branch_delay;
                    end if;
                when "000111" =>    -- bgtz
                    if to_integer(signed(reg(rs))) > 0 then
                        pc <= pc + imm*4;
                        addra <= std_logic_vector(to_unsigned(pc/4 + imm, 12));
                        state <= branch_delay;
                    end if;
                when "000010" =>    -- j
                    pc <= target*4;
                    addra <= std_logic_vector(to_unsigned(target, 12));
                    state <= branch_delay;
                when "000011" =>    -- jal
                    reg(31) <= std_logic_vector(to_unsigned(pc, 32));
                    pc <= target*4;
                    addra <= std_logic_vector(to_unsigned(target, 12));
                    state <= branch_delay;
                when others =>
                end case;
            when lw_delay =>
                addra <= std_logic_vector(to_unsigned(pc/4, 12));
                state <= lw_final;
            when lw_final =>
                addra <= std_logic_vector(to_unsigned(pc/4 + 1, 12));
                pc <= pc + 4;
                reg(rt_tmp) <= doutb;
                rr <= rt_tmp;
                state <= exec;
            when sw_final =>
                addra <= std_logic_vector(to_unsigned(pc/4 + 1, 12));
                pc <= pc + 4;
                web <= "0";
                state <= exec;
            when done =>
                cycle <= cycle;
            end case;
        end if;
    end process;
end behavioral;