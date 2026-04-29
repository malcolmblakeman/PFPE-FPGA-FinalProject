library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

library work;
use work.Bus_Interface_Common.all;

entity PI_Buck is
	Port( clk: in std_logic;
		rst: in std_logic;
		Data: INOUT std_logic_vector(15 downto 0);
		Addr: OUT std_logic_vector(15 downto 0);
		Xrqst: OUT std_logic;
		XDat: IN std_logic;
		YDat: OUT std_logic;
		BusRqst: OUT std_logic;
		BusCtrl: IN std_logic
		);
end PI_Buck;

architecture Behavioral of PI_Buck is
	type state_type is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12,S13,S14,S15,S16);
	signal CS_Bus, NS_Bus: state_type;

	component Std_Counter is
	generic( Width: integer);
	Port( INC,rst,clk: in std_logic;
	Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
	end component;

	COMPONENT Bus_Int 
	port(clk: in std_logic;
		rst: in std_logic;
		DataIn: in std_logic_vector(15 downto 0);
		DataOut: out std_logic_vector(15 downto 0);
		AddrIn: in std_logic_vector(15 downto 0);
		WE: in std_logic;
		RE: in std_logic;
		Busy: out std_logic;
		Data: inout std_logic_vector(15 downto 0);
		Addr: out std_logic_vector(15 downto 0);
		Xrqst: out std_logic;
		XDat: in std_logic;
		YDat: out std_logic;
		BusRqst: out std_logic;
		BusCtrl: in std_logic
		);
	end COMPONENT;

	constant Cmd_Max: std_logic_vector(15 downto 0) := X"0F00";
	constant Cmd_Min: std_logic_vector(15 downto 0) := X"0000";

	constant P_Shift: integer := 1;
	constant I_Shift: integer := 1;

	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy : STD_LOGIC:= '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Bus_Cnt_rst, Bus_Cnt_INC: std_logic := '0';
	signal Bus_Cnt_Out: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Delay_Cnt_rst, Delay_Cnt_INC: std_logic := '0';
	signal Delay_Cnt_Out: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	
	signal Cmd_In, Cmd_In_reg_o: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Mea_In, Mea_In_reg_o: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Cmd_Out, Cmd_Temp: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal LD_Cmd_In, LD_Mea_In, LD_Cmd_Out: std_logic := '0';
	
	signal Err_S_Temp, Err_S_reg_o: std_logic := '0';
	signal Acc_S_Temp, Acc_S_reg_o: std_logic := '0';
	signal Err, Err_reg_o: signed(31 downto 0) := (others => '0');
	signal P_Temp, P_reg_o: signed(31 downto 0) := (others => '0');
	signal Acc_Temp, Acc_reg_o: signed(31 downto 0) := (others => '0');
	signal I_Temp, I_reg_o: signed(31 downto 0) := (others => '0');
	signal LD_Err, LD_Err_S, LD_P, LD_Acc, LD_Acc_S, LD_I: std_logic := '0';
	signal Acc_Temp_17b, Acc_Temp_17b_reg_o: signed(31 downto 0) := (others => '0');
	signal Cmd_Temp_17b, Cmd_Temp_17b_reg_o: signed(31 downto 0) := (others => '0');
	signal LD_Acc_Temp_17b, LD_Cmd_Temp_17b: std_logic := '0';
	signal LD_Cmd_Temp_s, Cmd_Temp_s, Cmd_Out_s: std_logic := '0';
begin
	Bus_Cnt: Std_Counter
	generic map( Width => 16)
	port map(clk => clk, rst => Bus_Cnt_rst, INC => Bus_Cnt_INC, Count => Bus_Cnt_Out);
	
	Delay_Cnt: Std_Counter
	generic map(Width => 16)
	port map(clk => clk, rst => Delay_Cnt_rst, INC => Delay_Cnt_INC, Count => Delay_Cnt_Out);
	
	Bus_Int1: Bus_Int PORT MAP(
	clk => clk,
	rst => rst,
	DataIn => Bus_Int1_DataIn,
	DataOut  => Bus_Int1_DataOut,
	AddrIn  => Bus_Int1_AddrIn,
	WE  => Bus_Int1_WE,
	RE  => Bus_Int1_RE,
	Busy  => Bus_Int1_Busy,
	Data => Data,
	Addr => Addr,
	Xrqst => Xrqst,
	XDat => Xdat,
	Ydat => Ydat,
	BusRqst => BusRqst,
	BusCtrl => BusCtrl
	);
	
	Reg_Proc: process
	begin
	wait until clk'event and clk = '1';
	if(rst = '0') then
		Cmd_In_reg_o <= (others => '0');
		Mea_In_reg_o <= (others => '0');
		Cmd_Out <= (others => '0');
		Cmd_Out_s <= '0';
		Err_reg_o <= (others => '0');
		P_reg_o <= (others => '0');
		Acc_reg_o <= (others => '0');
		I_reg_o <= (others => '0');
		Err_S_reg_o <= '0';
		Acc_S_reg_o <= '0';
		Acc_Temp_17b_reg_o <= (others => '0');
		Cmd_Temp_17b_reg_o <= (others => '0');
	else
		if(LD_Cmd_In = '1') then Cmd_In_reg_o <= Bus_Int1_DataOut; end if;
		if(LD_Mea_In = '1') then Mea_In_reg_o <= Bus_Int1_DataOut; end if;
		if(LD_Cmd_Out = '1') then Cmd_Out <= Cmd_Temp; end if;
		if(LD_Cmd_Temp_s = '1') then Cmd_Out_s <= Cmd_Temp_s; end if;
		if(LD_Err = '1') then Err_reg_o <= Err; end if;
		if(LD_P = '1') then P_reg_o <= P_Temp; end if;
		if(LD_Acc = '1') then Acc_reg_o <= Acc_Temp; end if;
		if(LD_I = '1') then I_reg_o <= I_Temp; end if;
		if(LD_Err_S = '1') then Err_S_reg_o <= Err_S_Temp; end if;
		if(LD_Acc_S = '1') then Acc_S_reg_o <= Acc_S_Temp; end if;
		if(LD_Acc_Temp_17b = '1') then Acc_Temp_17b_reg_o <= Acc_Temp_17b; end if;
		if(LD_Cmd_Temp_17b = '1') then Cmd_Temp_17b_reg_o <= Cmd_Temp_17b; end if;
	end if;
	end process;
	
	NSL_Bus: process(CS_Bus, Bus_Cnt_Out, Bus_Int1_Busy, Delay_Cnt_Out, Cmd_In_reg_o, Mea_In_reg_o, Err_reg_o, Err_S_reg_o, Acc_S_reg_o, Acc_Temp_17b_reg_o, Cmd_Temp_17b_reg_o, Acc_reg_o, P_reg_o, I_reg_o)
	begin
	NS_Bus <= S0;
	Bus_Int1_AddrIn <= (others => '0');
	Bus_Int1_DataIn <= (others => '0');
	Bus_Int1_RE <= '0';
	Bus_Int1_WE <= '0';
	Bus_Cnt_rst <= '1';
	Bus_Cnt_INC <= '0';
	Delay_Cnt_rst <= '1';
	Delay_Cnt_INC <= '0';
	
	LD_Cmd_In <= '0';
	LD_Mea_In <= '0';
	LD_Cmd_Out <= '0';
	LD_Err <= '0';
	LD_P <= '0';
	LD_Acc <= '0';
	LD_I <= '0';
	Cmd_Temp <= (others => '0');
	Err <= (others => '0');
	Err_S_Temp <= '0';
	Acc_S_Temp <= '0';
	LD_Err_S <= '0';
	LD_Acc_S <= '0';
	Acc_Temp_17b <= (others => '0');
	LD_Acc_Temp_17b <= '0';
	Cmd_Temp_17b <= (others => '0');
	LD_Cmd_Temp_17b <= '0';
	Acc_Temp <= (others => '0');
	P_Temp <= (others => '0');
	I_Temp <= (others => '0');
	Cmd_Temp_s <= '0';
	LD_Cmd_Temp_s <= '0';
	
	case CS_Bus is
	when S0 =>
		Bus_Cnt_rst <= '0';
		Delay_Cnt_rst <= '0';
		NS_Bus <= S1;
	when S1 =>
		if(Delay_Cnt_Out < X"0800") then NS_Bus <= S1;
		else NS_Bus <= S2; end if;
		Delay_Cnt_INC <= '1';
	when S2 =>
		if(Bus_Cnt_Out < X"0FDE") then NS_Bus <= S2;
		else NS_Bus <= S3; end if;
		Bus_Cnt_INC <= '1';
	when S3 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S3;
		else NS_Bus <= S4; end if;
		Bus_Cnt_rst <= '0';
	when S4 =>
		Bus_Int1_AddrIn <= Addr_ADC1;
		Bus_Int1_RE <= '1';
		NS_Bus <= S5;
	when S5 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S5;
		else LD_Mea_In <= '1'; NS_Bus <= S6; end if;
	when S6 =>
		Bus_Int1_AddrIn <= Addr_Buck_SP;
		Bus_Int1_RE <= '1';
		NS_Bus <= S7;
	when S7 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S7;
		else LD_Cmd_In <= '1'; NS_Bus <= S8; end if;
	when S8 =>
		Err <= resize((signed(Cmd_In_reg_o) - signed(Mea_In_reg_o)),32);
		LD_Err <= '1';
		NS_Bus <= S9;
	when S9 =>
		I_Temp <= shift_right(Err_reg_o, 14);
		P_Temp <= shift_right(Err_reg_o,2);
		LD_I <= '1';
		LD_P <= '1';
		NS_Bus <= S10;
	when S10 =>
		Acc_Temp_17b <= Acc_reg_o + I_reg_o;
		LD_Acc_Temp_17b <= '1';
		NS_Bus <= S11;
	when S11 =>
		if(Acc_Temp_17b_reg_o > 65535) then Acc_Temp <= X"0000FFFF";
		elsif(Acc_Temp_17b_reg_o < 0) then Acc_Temp <= X"00000000";
		else Acc_Temp <= Acc_Temp_17b_reg_o; end if;
		LD_Acc <= '1';
		NS_Bus <= S12;
	when S12 =>
		Cmd_Temp_17b <= Acc_reg_o + P_reg_o;
		LD_Cmd_Temp_17b <= '1';
		NS_Bus <= S13;
	when S13 =>
		if(Cmd_Temp_17b_reg_o > signed(Cmd_Max)) then Cmd_Temp <= Cmd_Max(15 downto 0);
		elsif(Cmd_Temp_17b_reg_o < signed(Cmd_Min)) then Cmd_Temp <= (others => '0');
		else Cmd_Temp <= std_logic_vector(Cmd_Temp_17b_reg_o(15 downto 0)); end if;
		LD_Cmd_Out <= '1';
		NS_Bus <= S14;
	when S14 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S14;
		else NS_Bus <= S15; end if;
	when S15 =>
		Bus_Int1_AddrIn <= Addr_Buck_DC;
		Bus_Int1_DataIn <= Cmd_Out;
		Bus_Int1_WE <= '1';
		NS_Bus <= S16;
	when S16 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S16;
		else NS_Bus <= S2; end if;
	when others =>
		NS_Bus <= S0;
	end case;
	end process;
	
	Sync_States: process
	begin
	wait until clk'event and clk = '1';
	if(rst = '0') then CS_Bus <= S0;
	else CS_Bus <= NS_Bus; end if;
	end process;
end Behavioral;