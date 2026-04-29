library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.numeric_std.all;
library work;
use work.Bus_Interface_Common.all;
entity LED_Ctrl is
	Port(clk: in std_logic;
		rst: in std_logic;
		Data: inout std_logic_vector(15 downto 0);
		Addr: OUT std_logic_vector(15 downto 0);
		Xrqst : OUT std_logic;
		XDat : IN std_logic;
		YDat : OUT std_logic;
		BusRqst : OUT std_logic;
		BusCtrl : IN std_logic;
		LED_En: out std_logic;
		LED1_Out: out std_logic;
		LED2_Out: out std_logic;
		LED3_Out: out std_logic;
		LED4_Out: out std_logic;
		LED5_Out: out std_logic;
		LED6_Out: out std_logic;
		LED7_Out: out std_logic;
		LED8_Out: out std_logic
		);
end LED_Ctrl;

architecture Behavioral of LED_Ctrl is
	type state_type is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12,S13,S14,S15,S16,S17);
	signal CS_Bus, NS_Bus, CS_PWM1, NS_PWM1, CS_PWM2, NS_PWM2, CS_PWM3, NS_PWM3, CS_PWM4, NS_PWM4: state_type;
	
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
	
	signal PWM_En, PWM_PRD, PWM_PW, PWM1_DC, PWM2_DC, PWM3_DC, PWM4_DC: STD_LOGIC_VECTOR(15 downto 0) := X"0000";
	signal PWM1_En, PWM2_En, PWM3_En, PWM4_En: STD_LOGIC := '0';
	
	constant PWM_Max: std_logic_vector(15 downto 0) := X"FFFF";
	constant PWM_Min: std_logic_vector(15 downto 0) := X"0000";
	
	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy : STD_LOGIC:= '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Bus_Cnt_rst, Bus_Cnt_INC: std_logic := '0';
	signal Bus_Cnt_Out: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Delay_Cnt_rst, Delay_Cnt_INC: std_logic := '0';
	signal Delay_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	signal LD_PWM_En, LD_PWM_PRD, LD_PWM_PW, LD_PWM1_DC,LD_PWM2_DC,LD_PWM3_DC,LD_PWM4_DC : STD_LOGIC := '0';
	signal PWM1_Cnt_rst, PWM1_Cnt_INC, PWM2_Cnt_rst, PWM2_Cnt_INC, PWM3_Cnt_rst, PWM3_Cnt_INC, PWM4_Cnt_rst, PWM4_Cnt_INC : STD_LOGIC := '0';
	signal PWM1_Cnt_Out,PWM2_Cnt_Out,PWM3_Cnt_Out,PWM4_Cnt_Out : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
begin
	Bus_Cnt: Std_Counter
	generic map( Width => 16)
	port map(clk => clk, rst => Bus_Cnt_rst, INC => Bus_Cnt_INC, Count => Bus_Cnt_Out);
	
	Delay_Cnt: Std_Counter
	generic map(Width => 8)
	port map(clk => clk, rst => Delay_Cnt_rst, INC => Delay_Cnt_INC, Count => Delay_Cnt_Out);
	
	PWM1_Cnt: Std_Counter
	generic map(Width => 16)
	port map(clk => clk, rst => PWM1_Cnt_rst, INC => PWM1_Cnt_INC, Count => PWM1_Cnt_Out);
	
	PWM2_Cnt: Std_Counter
	generic map(Width => 16)
	port map(clk => clk, rst => PWM2_Cnt_rst, INC => PWM2_Cnt_INC, Count => PWM2_Cnt_Out);
	
	PWM3_Cnt: Std_Counter
	generic map(Width => 16)
	port map(clk => clk, rst => PWM3_Cnt_rst, INC => PWM3_Cnt_INC, Count => PWM3_Cnt_Out);
	
	PWM4_Cnt: Std_Counter
	generic map(Width => 16)
	port map(clk => clk, rst => PWM4_Cnt_rst, INC => PWM4_Cnt_INC, Count => PWM4_Cnt_Out);
	
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
	if rst = '0' then
		PWM1_DC <= (others => '0');
		PWM2_DC <= (others => '0');
		PWM3_DC <= (others => '0');
		PWM4_DC <= (others => '0');
		PWM_PRD <= (others => '0');
		PWM_En <= (others => '0');
		LED_En <= '0';
	else
		if(LD_PWM1_DC = '1') then PWM1_DC <= Bus_Int1_DataOut; end if;
		if(LD_PWM2_DC = '1') then PWM2_DC <= Bus_Int1_DataOut; end if;
		if(LD_PWM3_DC = '1') then PWM3_DC <= Bus_Int1_DataOut; end if;
		if(LD_PWM4_DC = '1') then PWM4_DC <= Bus_Int1_DataOut; end if;
		if(LD_PWM_PRD = '1') then PWM_PRD <= Bus_Int1_DataOut; end if;
		if(LD_PWM_En = '1') then PWM_En <= Bus_Int1_DataOut; end if;
		LED_En <= '1';
	end if;
	end process;
	
	NSL_Bus: process(CS_Bus, Bus_Cnt_Out, Bus_Int1_Busy, Delay_Cnt_Out)
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
	LD_PWM1_DC <= '0';
	LD_PWM2_DC <= '0';
	LD_PWM3_DC <= '0';
	LD_PWM4_DC <= '0';
	LD_PWM_PRD <= '0';
	LD_PWM_En <= '0';
	LED5_Out <= '0';
	LED6_Out <= '0';
	LED7_Out <= '0';
	LED8_Out <= '0';
	
	case CS_Bus is
	when S0 =>
		Bus_Cnt_rst <= '0';
		Delay_Cnt_rst <= '0';
		NS_Bus <= S1;
	when S1 =>
		if(Delay_Cnt_Out < 40) then NS_Bus <= S1;
		else NS_Bus <= S2; end if;
		Delay_Cnt_INC <= '1';
	when S2 => 
		if(Bus_Cnt_Out < 4062) then NS_Bus <= S2;
		else NS_Bus <= S3; end if;
		Bus_Cnt_INC <= '1';
	when S3 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S3;
		else NS_Bus <= S4; end if;
		Bus_Cnt_rst <= '0';
	when S4 =>
		Bus_Int1_AddrIn <= Addr_LED_En;
		Bus_Int1_RE <= '1';
		NS_Bus <= S5;
	when S5 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S5;
		else LD_PWM_En <= '1'; NS_Bus <= S6; end if;
	when S6 =>
		Bus_Int1_AddrIn <= Addr_LED_PRD;
		Bus_Int1_RE <= '1';
		NS_Bus <= S7;
	when S7 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S7;
		else LD_PWM_PRD <= '1'; NS_Bus <= S8; end if;
	when S8 =>
		Bus_Int1_AddrIn <= Addr_LED_PW;
		Bus_Int1_RE <= '1';
		NS_Bus <= S9;
	when S9 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S9;
		else LD_PWM_PW <= '1'; NS_Bus <= S10; end if;
	when S10 =>
		Bus_Int1_AddrIn <= Addr_Buck_DC;
		Bus_Int1_RE <= '1';
		NS_Bus <= S11;
	when S11 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S11;
		else LD_PWM1_DC <= '1'; NS_Bus <= S12; end if;
	when S12 =>
		Bus_Int1_AddrIn <= Addr_LED2_DC;
		Bus_Int1_RE <= '1';
		NS_Bus <= S13;
	when S13 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S13;
		else LD_PWM2_DC <= '1'; NS_Bus <= S14; end if;
	when S14 =>
		Bus_Int1_AddrIn <= Addr_LED3_DC;
		Bus_Int1_RE <= '1';
		NS_Bus <= S15;
	when S15 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S15;
		else LD_PWM3_DC <= '1'; NS_Bus <= S16; end if;
	when S16 =>
		Bus_Int1_AddrIn <= Addr_LED4_DC;
		Bus_Int1_RE <= '1';
		NS_Bus <= S17;
	when S17 =>
		if(Bus_Int1_Busy = '1') then NS_Bus <= S17;
		else LD_PWM4_DC <= '1'; NS_Bus <= S2; end if;
	when others =>
		NS_Bus <= S0;
	end case;
	end process;
	
	NSL_PWM1: process(CS_PWM1, PWM1_Cnt_Out, PWM_PRD, PWM1_DC)
	begin
	NS_PWM1 <= S0;
	PWM1_Cnt_rst <= '1';
	PWM1_Cnt_INC <= '0';
	LED1_Out <= '0';
	
	case CS_PWM1 is
	when S0 =>
		PWM1_Cnt_rst <= '0';
		NS_PWM1 <= S1;
	when S1 =>
		if(PWM1_Cnt_Out < PWM1_DC) then NS_PWM1 <= S1;
		else NS_PWM1 <= S2; end if;
		PWM1_Cnt_INC <= '1';
		LED1_Out <= '1';
	when S2 =>
		if(PWM1_Cnt_Out < PWM_PRD) then NS_PWM1 <= S2;
		else NS_PWM1 <= S0; end if;
		PWM1_Cnt_INC <= '1';
	when others =>
		NS_PWM1 <= S0;
	end case;
	end process;
	
	NSL_PWM2: process(CS_PWM2, PWM2_Cnt_Out, PWM_PRD, PWM2_DC)
	begin
	NS_PWM2 <= S0;
	PWM2_Cnt_rst <= '1';
	PWM2_Cnt_INC <= '0';
	LED2_Out <= '0';
	
	case CS_PWM2 is
	when S0 =>
		PWM2_Cnt_rst <= '0';
		NS_PWM2 <= S1;
	when S1 =>
		if(PWM2_Cnt_Out < PWM2_DC) then NS_PWM2 <= S1;
		else NS_PWM2 <= S2; end if;
		PWM2_Cnt_INC <= '1';
		LED2_Out <= '1';
	when S2 =>
		if(PWM2_Cnt_Out < PWM_PRD) then NS_PWM2 <= S2;
		else NS_PWM2 <= S0; end if;
		PWM2_Cnt_INC <= '1';
	when others =>
		NS_PWM2 <= S0;
	end case;
	end process;
	
	NSL_PWM3: process(CS_PWM3, PWM3_Cnt_Out, PWM_PRD, PWM3_DC)
	begin
	NS_PWM3 <= S0;
	PWM3_Cnt_rst <= '1';
	PWM3_Cnt_INC <= '0';
	LED3_Out <= '0';
	
	case CS_PWM3 is
	when S0 =>
		PWM3_Cnt_rst <= '0';
		NS_PWM3 <= S1;
	when S1 =>
		if(PWM3_Cnt_Out < PWM3_DC) then NS_PWM3 <= S1;
		else NS_PWM3 <= S2; end if;
		PWM3_Cnt_INC <= '1';
		LED3_Out <= '1';
	when S2 =>
		if(PWM3_Cnt_Out < PWM_PRD) then NS_PWM3 <= S2;
		else NS_PWM3 <= S0; end if;
		PWM3_Cnt_INC <= '1';
	when others =>
		NS_PWM3 <= S0;
	end case;
	end process;
	
	NSL_PWM4: process(CS_PWM4, PWM4_Cnt_Out, PWM_PRD, PWM4_DC)
	begin
	NS_PWM4 <= S0;
	PWM4_Cnt_rst <= '1';
	PWM4_Cnt_INC <= '0';
	LED4_Out <= '0';
	
	case CS_PWM4 is
	when S0 =>
		PWM4_Cnt_rst <= '0';
		NS_PWM4 <= S1;
	when S1 =>
		if(PWM4_Cnt_Out < PWM4_DC) then NS_PWM4 <= S1;
		else NS_PWM4 <= S2; end if;
		PWM4_Cnt_INC <= '1';
		LED4_Out <= '1';
	when S2 =>
		if(PWM4_Cnt_Out < PWM_PRD) then NS_PWM4 <= S2;
		else NS_PWM4 <= S0; end if;
		PWM4_Cnt_INC <= '1';
	when others =>
		NS_PWM4 <= S0;
	end case;
	end process;
	
	Sync_States: process
	begin
	wait until clk'event and clk = '1';
	if(rst = '0') then CS_Bus <= S0;
	else CS_Bus <= NS_Bus; end if;
	end process;
	
	Sync_PWM: process
	begin
	wait until clk'event and clk = '1';
	if(rst = '0' or PWM_En = X"0000") then CS_PWM1 <= S0;CS_PWM2 <= S0;CS_PWM3 <= S0;CS_PWM4 <= S0;
	else CS_PWM1 <= NS_PWM1;CS_PWM2 <= NS_PWM2;CS_PWM3 <= NS_PWM3;CS_PWM4 <= NS_PWM4; end if;
	end process;
end Behavioral;