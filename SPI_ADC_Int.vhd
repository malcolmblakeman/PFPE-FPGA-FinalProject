library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity SPI_ROM is
	port(rst, clk, D_Sel: in std_logic;
		data: out std_logic_vector(15 downto 0));
	end;
	
architecture behavior of SPI_ROM is
begin
	SPI_ROM_behav: process
	begin
	wait until clk'event and clk = '1';
	if rst = '0' then data <= (others => '0');
	else 
	if D_Sel = '0' then data <= X"FFDF";
	else data <= X"FFFF"; end if;
	end if;
	end process;
end behavior;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.numeric_std.all;

library work;
use work.Bus_Interface_Common.all;

entity ADC_Int is
	Port( clk: in std_logic;
		rst: in std_logic;
		Data: inout std_logic_vector(15 downto 0);
		Addr: out std_logic_vector(15 downto 0);
		Xrqst: out std_logic;
		XDat: in std_logic;
		YDat: out std_logic;
		BusRqst: out std_logic;
		BusCtrl: in std_logic;
		SPI_Sclk: inout std_logic;
		SPI_Din: inout std_logic;
		SPI_Csn: out std_logic;
		SPI_Dout: in std_logic
		);
end ADC_Int;

architecture Behavioral of ADC_Int is
	constant Chan: STD_LOGIC_VECTOR(2 downto 0) := b"111";
	constant Delay: STD_LOGIC_VECTOR(15 downto 0) := X"00BA";
	constant Offset_Chan: STD_LOGIC_VECTOR(7 downto 0) := X"07";
	constant Offset_Set: STD_LOGIC_VECTOR(7 downto 0) := X"1E";
	constant Sample_Size: integer := 2;
	
	type state_type is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,S11,S12,S13,S14,S15,S16,S17,S18);
	signal CS_ADC_Ctrl, NS_ADC_Ctrl, CS_Bus_Ctrl, NS_Bus_Ctrl: state_type := S0;
	
	signal SPI_Cnt_INC, SPI_Cnt_rst, Prg_Cnt_INC, Prg_Cnt_rst, Setup_Cnt_INC, Setup_Cnt_rst : std_logic := '0';
	signal Prg_Cnt_Out, Setup_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	signal Spi_Cnt_Out: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	
	signal SPI_ROM1_D_SEL: std_logic := '0';
	signal SPI_ROM1_data : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	
	signal SPI_PS_ld_D, SPI_PS_sh_D, SPI_PS_rst : std_logic := '0';
	signal SPI_SP_ld_D, SPI_SP_rst : std_logic := '0';
	signal SPI_SP1_Data_Out, SPI_SP2_Data_Out: std_logic_vector(15 downto 0) := (others => '0');
	
	signal SPI_Dout1_Sync, SPI_Dout2_Sync: std_logic := '0';
	
	type Memory is array(15 downto 0) of STD_LOGIC_VECTOR(15 downto 0);
	signal ADC_Mem: Memory;
	signal ADC_wea: std_logic := '0';
	signal ADC_Mem_Ave: Memory;
	signal ADC_Ave_Ld, ADC_Ave_En: std_logic := '0';
	signal ADC_Mem_Temp: Memory;
	signal ADC_Temp_rst : std_logic := '0';
	signal Ave_Cnt_INC, Ave_Cnt_rst : std_logic := '0';
	signal ADC_Mem_Ave_M1, ADC_Mem_Ave_M2: Memory;
	signal Ave_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy : STD_LOGIC:= '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Bus_Cnt_rst, Bus_Cnt_INC: std_logic := '0';
	signal Bus_Cnt_Out: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Mem_Addr_Cnt_rst, Mem_Addr_Cnt_INC: std_logic := '0';
	signal Mem_Addr_Cnt_Out: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	signal clk_temp2 : std_logic_vector(3 downto 0) := (others => '0');
	signal clk_SPI: std_logic := '0';
	
	signal SPI_CNT_Loop_INC, SPI_CNT_Loop_rst : std_logic := '0';
	signal SPI_CNT_Loop_Out: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	
	component Std_Counter is
	generic( Width: integer);
	Port( INC,rst,clk: in std_logic;
	Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
	end component;
	
	component SPI_ROM is
	Port( clk: in std_logic;
		rst: in std_logic;
		D_Sel: in std_logic;
		data: out std_logic_vector(15 downto 0));
	end component;
	
	component Sreg_PS_16 is
	Port( clk: in STD_LOGIC;
		rst: in STD_LOGIC;
		ld_D: in STD_LOGIC;
		sh_D: in STD_LOGIC;
		Data_In: in STD_LOGIC_VECTOR(15 downto 0);
		Data_Out: out std_logic);
	end component;
	
	component Sreg_SP_16 is
	Port( clk: in STD_LOGIC;
		rst: in STD_LOGIC;
		ld_D: in STD_LOGIC;
		Data_In: in STD_LOGIC;
		Data_Out: out std_logic_vector(15 downto 0));
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
	
begin
	SPI_sclk <= clk_SPI;
	
	SPI_Cnt: STD_Counter
	generic map( Width => 16)
	port map( clk=> clk_SPI, rst => SPI_Cnt_rst, INC => SPI_Cnt_INC, Count => SPI_Cnt_Out);
	
	Prg_Cnt: STD_Counter
	generic map( Width => 8)
	port map( clk=> clk_SPI, rst => Prg_Cnt_rst, INC => Prg_Cnt_INC, Count => Prg_Cnt_Out);
	
	Setup_Cnt: STD_Counter
	generic map( Width => 8)
	port map( clk=> clk_SPI, rst => Setup_Cnt_rst, INC => Setup_Cnt_INC, Count => Setup_Cnt_Out);
	
	Ave_Cnt: STD_Counter
	generic map( Width => 8)
	port map( clk=> clk_SPI, rst => Ave_Cnt_rst, INC => Ave_Cnt_INC, Count => Ave_Cnt_Out);
	
	Mem_Cnt: STD_Counter
	generic map( Width => 8)
	port map( clk=> clk_SPI, rst => Mem_Addr_Cnt_rst, INC => Mem_Addr_Cnt_INC, Count => Mem_Addr_Cnt_Out);
	
	SPI_ROM1: SPI_ROM port map(
		clk => clk_SPI,
		rst => rst,
		D_SEL => SPI_ROM1_D_SEL,
		data => SPI_ROM1_data);
		
	SPI_PS: Sreg_PS_16 port map(
		clk => clk_SPI,
		rst => SPI_PS_rst,
		ld_D => SPI_PS_ld_D,
		sh_D => SPI_PS_sh_D,
		Data_In => SPI_ROM1_data,
		Data_Out => SPI_Din);
		
	SPI_SP: Sreg_SP_16 port map(
		clk => clk_SPI,
		rst => SPI_SP_rst,
		ld_D => SPI_SP_ld_D,
		Data_In => SPI_Dout1_Sync,
		Data_Out => SPI_SP1_Data_Out);
		
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
		BusCtrl => BusCtrl);
		
	Bus_Cnt: Std_Counter
	generic map( Width => 16)
	port map(clk => clk, rst => Bus_Cnt_rst, INC => Bus_Cnt_INC, Count => Bus_Cnt_Out);
	
	SPI_Loop_Cnt: STD_Counter
	generic map( Width => 16)
	port map(clk => clk, rst => SPI_CNT_Loop_rst, INC => SPI_CNT_Loop_INC, Count => SPI_CNT_Loop_Out);
	
	ADC_Mem_W: process
	begin
		wait until clk_SPI'event and clk_SPI = '1';
		if rst = '0' then
			ADC_Mem(0) <= (others => '0');
			ADC_Mem(1) <= (others => '0');
			ADC_Mem(2) <= (others => '0');
			ADC_Mem(3) <= (others => '0');
			ADC_Mem(4) <= (others => '0');
			ADC_Mem(5) <= (others => '0');
			ADC_Mem(6) <= (others => '0');
			ADC_Mem(7) <= (others => '0');
			ADC_Mem(8) <= (others => '0');
			ADC_Mem(9) <= (others => '0');
			ADC_Mem(10) <= (others => '0');
			ADC_Mem(11) <= (others => '0');
			ADC_Mem(12) <= (others => '0');
			ADC_Mem(13) <= (others => '0');
			ADC_Mem(14) <= (others => '0');
			ADC_Mem(15) <= (others => '0');
			
			elsif ADC_wea = '1' then 
				if SPI_SP1_Data_Out(14 downto 12) = "000" then ADC_Mem(0) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
				if SPI_SP1_Data_Out(14 downto 12) = "001" then ADC_Mem(1) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
				if SPI_SP1_Data_Out(14 downto 12) = "010" then ADC_Mem(2) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
				if SPI_SP1_Data_Out(14 downto 12) = "011" then ADC_Mem(3) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
				if SPI_SP1_Data_Out(14 downto 12) = "100" then ADC_Mem(4) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
				if SPI_SP1_Data_Out(14 downto 12) = "101" then ADC_Mem(5) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
				if SPI_SP1_Data_Out(14 downto 12) = "110" then ADC_Mem(6) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
				if SPI_SP1_Data_Out(14 downto 12) = "111" then ADC_Mem(7) <= X"0" & SPI_SP1_Data_Out(11 downto 0); end if;
			end if;
		end process;
		
	Sample_Ave: process
	begin
	wait until clk_SPI'event and clk_SPI = '1';
	if(rst = '0' or ADC_Temp_rst = '0') then
		ADC_Mem_Temp(0) <= (others => '0');
		ADC_Mem_Temp(1) <= (others => '0');
		ADC_Mem_Temp(2) <= (others => '0');
		ADC_Mem_Temp(3) <= (others => '0');
		ADC_Mem_Temp(4) <= (others => '0');
		ADC_Mem_Temp(5) <= (others => '0');
		ADC_Mem_Temp(6) <= (others => '0');	
		ADC_Mem_Temp(7) <= (others => '0');
		ADC_Mem_Temp(8) <= (others => '0');
		ADC_Mem_Temp(9) <= (others => '0');
		ADC_Mem_Temp(10) <= (others => '0');
		ADC_Mem_Temp(11) <= (others => '0');
		ADC_Mem_Temp(12) <= (others => '0');
		ADC_Mem_Temp(13) <= (others => '0');
		ADC_Mem_Temp(14) <= (others => '0');
		ADC_Mem_Temp(15) <= (others => '0');
		
	elsif ADC_Ave_En = '1' then
		ADC_Mem_Temp(0)<= ADC_Mem(0) + ADC_Mem(0);
		ADC_Mem_Temp(1)<= ADC_Mem(1) + ADC_Mem(1);
		ADC_Mem_Temp(2)<= ADC_Mem(2) + ADC_Mem(2);
		ADC_Mem_Temp(3)<= ADC_Mem(3) + ADC_Mem(3);
		ADC_Mem_Temp(4)<= ADC_Mem(4) + ADC_Mem(4);
		ADC_Mem_Temp(5)<= ADC_Mem(5) + ADC_Mem(5);
		ADC_Mem_Temp(6)<= ADC_Mem(6) + ADC_Mem(6);
		ADC_Mem_Temp(7)<= ADC_Mem(7) + ADC_Mem(7);
		ADC_Mem_Temp(8)<= ADC_Mem(8) + ADC_Mem(8);
		ADC_Mem_Temp(9)<= ADC_Mem(9) + ADC_Mem(9);
		ADC_Mem_Temp(10)<= ADC_Mem(10) + ADC_Mem(10);
		ADC_Mem_Temp(11)<= ADC_Mem(11) + ADC_Mem(11);
		ADC_Mem_Temp(12)<= ADC_Mem(12) + ADC_Mem(12);
		ADC_Mem_Temp(13)<= ADC_Mem(13) + ADC_Mem(13);
		ADC_Mem_Temp(14)<= ADC_Mem(14) + ADC_Mem(14);
		ADC_Mem_Temp(15)<= ADC_Mem(15) + ADC_Mem(15);
	end if;
	end process;
	
	ADC_Mem_Ave_Reg: process
	begin
	wait until clk_SPI'event and clk_SPI = '1';
	if rst = '0' then
		ADC_Mem_Ave(0) <= (others => '0');
		ADC_Mem_Ave(1) <= (others => '0');
		ADC_Mem_Ave(2) <= (others => '0');
		ADC_Mem_Ave(3) <= (others => '0');
		ADC_Mem_Ave(4) <= (others => '0');
		ADC_Mem_Ave(5) <= (others => '0');
		ADC_Mem_Ave(6) <= (others => '0');
		ADC_Mem_Ave(7) <= (others => '0');
		ADC_Mem_Ave(8) <= (others => '0');
		ADC_Mem_Ave(9) <= (others => '0');
		ADC_Mem_Ave(10) <= (others => '0');
		ADC_Mem_Ave(11) <= (others => '0');
		ADC_Mem_Ave(12) <= (others => '0');
		ADC_Mem_Ave(13) <= (others => '0');
		ADC_Mem_Ave(14) <= (others => '0');
		ADC_Mem_Ave(15) <= (others => '0');
	elsif ADC_Ave_Ld = '1' then
		ADC_Mem_Ave(0) <= b"0" & ADC_Mem_Temp(0)(15 downto 1);
		ADC_Mem_Ave(1) <= b"0" & ADC_Mem_Temp(1)(15 downto 1);
		ADC_Mem_Ave(2) <= b"0" & ADC_Mem_Temp(2)(15 downto 1);
		ADC_Mem_Ave(3) <= b"0" & ADC_Mem_Temp(3)(15 downto 1);
		ADC_Mem_Ave(4) <= b"0" & ADC_Mem_Temp(4)(15 downto 1);
		ADC_Mem_Ave(5) <= b"0" & ADC_Mem_Temp(5)(15 downto 1);
		ADC_Mem_Ave(6) <= b"0" & ADC_Mem_Temp(6)(15 downto 1);
		ADC_Mem_Ave(7) <= b"0" & ADC_Mem_Temp(7)(15 downto 1);
		ADC_Mem_Ave(8) <= b"0" & ADC_Mem_Temp(8)(15 downto 1);
		ADC_Mem_Ave(9) <= b"0" & ADC_Mem_Temp(9)(15 downto 1);
		ADC_Mem_Ave(10) <= b"0" & ADC_Mem_Temp(10)(15 downto 1);
		ADC_Mem_Ave(11) <= b"0" & ADC_Mem_Temp(11)(15 downto 1);
		ADC_Mem_Ave(12) <= b"0" & ADC_Mem_Temp(12)(15 downto 1);
		ADC_Mem_Ave(13) <= b"0" & ADC_Mem_Temp(13)(15 downto 1);
		ADC_Mem_Ave(14) <= b"0" & ADC_Mem_Temp(14)(15 downto 1);
		ADC_Mem_Ave(15) <= b"0" & ADC_Mem_Temp(15)(15 downto 1);
	end if;
	end process;
	
	ADC_Mem_Ave_Reg_Meta: process
	begin
	wait until clk'event and clk = '1';
	if rst = '0' then
		ADC_Mem_Ave_M1(0) <= (others => '0');
		ADC_Mem_Ave_M1(1) <= (others => '0');
		ADC_Mem_Ave_M1(2) <= (others => '0');
		ADC_Mem_Ave_M1(3) <= (others => '0');
		ADC_Mem_Ave_M1(4) <= (others => '0');
		ADC_Mem_Ave_M1(5) <= (others => '0');
		ADC_Mem_Ave_M1(6) <= (others => '0');
		ADC_Mem_Ave_M1(7) <= (others => '0');
		ADC_Mem_Ave_M1(8) <= (others => '0');
		ADC_Mem_Ave_M1(9) <= (others => '0');
		ADC_Mem_Ave_M1(10) <= (others => '0');
		ADC_Mem_Ave_M1(11) <= (others => '0');
		ADC_Mem_Ave_M1(12) <= (others => '0');
		ADC_Mem_Ave_M1(13) <= (others => '0');
		ADC_Mem_Ave_M1(14) <= (others => '0');
		ADC_Mem_Ave_M1(15) <= (others => '0');
		ADC_Mem_Ave_M2(0) <= (others => '0');
		ADC_Mem_Ave_M2(1) <= (others => '0');
		ADC_Mem_Ave_M2(2) <= (others => '0');
		ADC_Mem_Ave_M2(3) <= (others => '0');
		ADC_Mem_Ave_M2(4) <= (others => '0');
		ADC_Mem_Ave_M2(5) <= (others => '0');
		ADC_Mem_Ave_M2(6) <= (others => '0');
		ADC_Mem_Ave_M2(7) <= (others => '0');
		ADC_Mem_Ave_M2(8) <= (others => '0');
		ADC_Mem_Ave_M2(9) <= (others => '0');
		ADC_Mem_Ave_M2(10) <= (others => '0');
		ADC_Mem_Ave_M2(11) <= (others => '0');
		ADC_Mem_Ave_M2(12) <= (others => '0');
		ADC_Mem_Ave_M2(13) <= (others => '0');
		ADC_Mem_Ave_M2(14) <= (others => '0');
		ADC_Mem_Ave_M2(15) <= (others => '0');
	else
		ADC_Mem_Ave_M1(0) <= ADC_Mem_Ave_M1(0);
		ADC_Mem_Ave_M1(1) <= ADC_Mem_Ave_M1(1);
		ADC_Mem_Ave_M1(2) <= ADC_Mem_Ave_M1(2);
		ADC_Mem_Ave_M1(3) <= ADC_Mem_Ave_M1(3);
		ADC_Mem_Ave_M1(4) <= ADC_Mem_Ave_M1(4);
		ADC_Mem_Ave_M1(5) <= ADC_Mem_Ave_M1(5);
		ADC_Mem_Ave_M1(6) <= ADC_Mem_Ave_M1(6);
		ADC_Mem_Ave_M1(7) <= ADC_Mem_Ave_M1(7);
		ADC_Mem_Ave_M1(8) <= ADC_Mem_Ave_M1(8);
		ADC_Mem_Ave_M1(9) <= ADC_Mem_Ave_M1(9);
		ADC_Mem_Ave_M1(10) <= ADC_Mem_Ave_M1(10);
		ADC_Mem_Ave_M1(11) <= ADC_Mem_Ave_M1(11);
		ADC_Mem_Ave_M1(12) <= ADC_Mem_Ave_M1(12);
		ADC_Mem_Ave_M1(13) <= ADC_Mem_Ave_M1(13);
		ADC_Mem_Ave_M1(14) <= ADC_Mem_Ave_M1(14);
		ADC_Mem_Ave_M1(15) <= ADC_Mem_Ave_M1(15);
		ADC_Mem_Ave_M2(0) <= ADC_Mem_Ave_M2(0);
		ADC_Mem_Ave_M2(1) <= ADC_Mem_Ave_M2(1);
		ADC_Mem_Ave_M2(2) <= ADC_Mem_Ave_M2(2);
		ADC_Mem_Ave_M2(3) <= ADC_Mem_Ave_M2(3);
		ADC_Mem_Ave_M2(4) <= ADC_Mem_Ave_M2(4);
		ADC_Mem_Ave_M2(5) <= ADC_Mem_Ave_M2(5);
		ADC_Mem_Ave_M2(6) <= ADC_Mem_Ave_M2(6);
		ADC_Mem_Ave_M2(7) <= ADC_Mem_Ave_M2(7);
		ADC_Mem_Ave_M2(8) <= ADC_Mem_Ave_M2(8);
		ADC_Mem_Ave_M2(9) <= ADC_Mem_Ave_M2(9);
		ADC_Mem_Ave_M2(10) <= ADC_Mem_Ave_M2(10);
		ADC_Mem_Ave_M2(11) <= ADC_Mem_Ave_M2(11);
		ADC_Mem_Ave_M2(12) <= ADC_Mem_Ave_M2(12);
		ADC_Mem_Ave_M2(13) <= ADC_Mem_Ave_M2(13);
		ADC_Mem_Ave_M2(14) <= ADC_Mem_Ave_M2(14);
		ADC_Mem_Ave_M2(15) <= ADC_Mem_Ave_M2(15);
	end if;
	end process;
	
	ADC_Ctrl: process(SPI_Dout1_Sync, SPI_Dout2_Sync, NS_ADC_Ctrl, CS_ADC_Ctrl, SPI_CNT_Out, Prg_Cnt_Out, Setup_Cnt_Out, Ave_Cnt_Out, SPI_CNT_Loop_Out)
	begin
	SPI_ROM1_D_SEL <= '0';
	SPI_PS_rst <= '1';
	SPI_PS_ld_D <= '0';
	SPI_PS_sh_D <= '0';
	SPI_Cnt_rst <= '1';
	SPI_Cnt_INC <= '0';
	Setup_Cnt_rst <= '1';
	Setup_Cnt_INC <= '0';
	Prg_Cnt_rst <= '1';
	Prg_Cnt_INC <= '0';
	
	SPI_CSn <= '1';
	SPI_SP_rst <= '1';
	SPI_SP_ld_D <= '0';
	
	ADC_wea <= '0';
	ADC_Ave_En <= '0';
	Ave_Cnt_rst <= '1';
	Ave_Cnt_INC <= '0';
	ADC_Temp_rst <= '1';
	ADC_Ave_Ld <= '0';
	
	SPI_CNT_Loop_rst <= '1';
	SPI_CNT_Loop_INC <= '0';
	
	case CS_ADC_Ctrl is
		when S0 =>
			SPI_Cnt_rst <= '0';
			Setup_Cnt_rst <= '0';
			Prg_Cnt_rst <= '0';
			SPI_SP_rst <= '0';
			SPI_PS_rst <= '0';
			ADC_Temp_rst <= '0';
			Ave_Cnt_rst <= '0';
			SPI_CNT_Loop_rst <= '0';
			NS_ADC_Ctrl <= S1;
		when S1 =>
			if(SPI_Cnt_Out < Delay) then
				SPI_Cnt_INC <= '1';
				NS_ADC_Ctrl <= S1;
			else
				SPI_Cnt_rst <= '0';
				NS_ADC_Ctrl <= S2;
			end if;
		when S2 =>
			SPI_ROM1_D_SEL <= '1';
			SPI_PS_ld_D <= '1';
			SPI_Cnt_rst <= '0';
			NS_ADC_Ctrl <= S3;
		when S3 =>
			SPI_ROM1_D_SEL <= '1';
			SPI_PS_ld_D <= '1';
			NS_ADC_Ctrl <= S4;
		when S4 =>
			NS_ADC_Ctrl <= S5;
		when S5 =>
			SPI_CSn <= '0';
			if(SPI_Cnt_Out < 15) then
				SPI_Cnt_INC <= '1';
				NS_ADC_Ctrl <= S5;
			elsif Setup_Cnt_Out < 1 then
				Setup_Cnt_INC <= '1';
				SPI_ROM1_D_SEL <= '1';
				NS_ADC_Ctrl <= S2;
			else
				SPI_Cnt_rst <= '0';
				NS_ADC_Ctrl <= S6;
			end if;
		when S6 =>
			if(SPI_Cnt_Out < 10) then
				SPI_Cnt_INC <= '1';
				NS_ADC_Ctrl <= S6;
			else NS_ADC_Ctrl <= S7; end if;
		when S7 =>
			SPI_Cnt_rst <= '0';
			SPI_SP_rst <= '0';
			Prg_Cnt_rst <= '0';
			SPI_PS_ld_D <= '1';
			NS_ADC_Ctrl <= S8;
		when S8 =>
			SPI_PS_sh_D <= '1';
			NS_ADC_Ctrl <= S9;
		when S9 =>
			SPI_PS_sh_D <= '1';
			SPI_Cnt_INC <= '1';
			SPI_CSn <= '0';
			if(SPI_Cnt_Out < 15) then NS_ADC_Ctrl <= S9;
			else NS_ADC_Ctrl <= S10; end if;
		when S10 =>
			SPI_Cnt_rst <= '0';
			SPI_SP_rst <= '0';
			NS_ADC_Ctrl <= S11;
		when S11 =>
			NS_ADC_Ctrl <= S12;
		when S12 =>
			SPI_Cnt_INC <= '1';
			SPI_CSn <= '0';
			SPI_SP_ld_D <= '1';
			if(SPI_Cnt_Out < 15) then NS_ADC_Ctrl <= S12;
			else NS_ADC_Ctrl <= S13; end if;
		when S13 =>
			SPI_Cnt_rst <= '0';
			NS_ADC_Ctrl <= S14;
		when S14 =>
			ADC_wea <= '1';
			NS_ADC_Ctrl <= S15;
		when S15 =>
			if(SPI_Cnt_Out < Offset_Chan) then
				SPI_Cnt_INC <= '1';
				NS_ADC_Ctrl <= S15;
			elsif(Prg_Cnt_Out < Chan) then
				Prg_Cnt_INC <= '1';
				NS_ADC_Ctrl <= S10;
			else
				SPI_Cnt_rst <= '0';
				Prg_Cnt_rst <= '0';
				Setup_Cnt_rst <= '0';
				NS_ADC_Ctrl <= S16;
			end if;
		when S16 =>
			if(Ave_Cnt_Out < (Sample_Size -1)) then NS_ADC_Ctrl <= S18;
			else NS_ADC_Ctrl <= S17; end if;
			ADC_Ave_En <= '1';
			Ave_Cnt_INC <= '1';
		when S17 =>
			ADC_Ave_Ld <= '1';
			ADC_Temp_rst <= '0';
			Ave_Cnt_rst <= '0';
			SPI_Cnt_INC <= '1';
			NS_ADC_Ctrl <= S18;
		when S18 =>
			if(SPI_Cnt_Out < Offset_Set) then
				SPI_Cnt_INC <= '1';
				NS_ADC_Ctrl <= S18;
			else
				SPI_Cnt_rst <= '0';
				Prg_Cnt_rst <= '0';
				if(SPI_Cnt_Loop_Out < 1000) then
					SPI_Cnt_Loop_INC <= '1';
					NS_ADC_Ctrl <= S10;
				else NS_ADC_Ctrl <= S0; end if;
			end if;
		when others =>
			NS_ADC_Ctrl <= S0;
	end case;
	end process;
	
	NSL_Bus: process(CS_Bus_Ctrl, Bus_Cnt_Out, Bus_Int1_Busy, Mem_Addr_Cnt_Out, ADC_Mem_Ave_M2)
	begin
	Bus_Int1_AddrIn <= (others => '0');
	Bus_Int1_DataIn <= (others => '0');
	Bus_Int1_RE <= '0';
	Bus_Int1_WE <= '0';
	Bus_Cnt_rst <= '1';
	Bus_Cnt_INC <= '0';
	Mem_Addr_Cnt_rst <= '1';
	Mem_Addr_Cnt_INC <= '0';
	
	case CS_Bus_Ctrl is
		when S0 =>
			Bus_Cnt_rst <= '0';
			Mem_Addr_Cnt_rst <= '0';
			NS_Bus_Ctrl <= S1;
		when S1 =>
			if(Bus_Cnt_Out < 4002) then NS_Bus_Ctrl <= S1;
			else NS_Bus_Ctrl <= S2; end if;
			Bus_Cnt_INC <= '1';
		when S2 =>
			if(Bus_Int1_Busy = '1') then NS_Bus_Ctrl <= S2;
			else NS_Bus_Ctrl <= S3; end if;
		when S3 =>
			if(Mem_Addr_Cnt_Out < 15) then NS_Bus_Ctrl <= S2;
			else NS_Bus_Ctrl <= S0; end if;
			
			if(Mem_Addr_Cnt_Out = 0) then Bus_Int1_AddrIn <= Addr_ADC0; end if;
			if(Mem_Addr_Cnt_Out = 1) then Bus_Int1_AddrIn <= Addr_ADC1; end if;
			if(Mem_Addr_Cnt_Out = 2) then Bus_Int1_AddrIn <= Addr_ADC2; end if;
			if(Mem_Addr_Cnt_Out = 3) then Bus_Int1_AddrIn <= Addr_ADC3; end if;
			if(Mem_Addr_Cnt_Out = 4) then Bus_Int1_AddrIn <= Addr_ADC4; end if;
			if(Mem_Addr_Cnt_Out = 5) then Bus_Int1_AddrIn <= Addr_ADC5; end if;
			if(Mem_Addr_Cnt_Out = 6) then Bus_Int1_AddrIn <= Addr_ADC6; end if;
			if(Mem_Addr_Cnt_Out = 7) then Bus_Int1_AddrIn <= Addr_ADC7; end if;
			if(Mem_Addr_Cnt_Out = 8) then Bus_Int1_AddrIn <= Addr_ADC8; end if;
			if(Mem_Addr_Cnt_Out = 9) then Bus_Int1_AddrIn <= Addr_ADC9; end if;
			if(Mem_Addr_Cnt_Out = 10) then Bus_Int1_AddrIn <= Addr_ADC10; end if;
			if(Mem_Addr_Cnt_Out = 11) then Bus_Int1_AddrIn <= Addr_ADC11; end if;
			if(Mem_Addr_Cnt_Out = 12) then Bus_Int1_AddrIn <= Addr_ADC12; end if;
			if(Mem_Addr_Cnt_Out = 13) then Bus_Int1_AddrIn <= Addr_ADC13; end if;
			if(Mem_Addr_Cnt_Out = 14) then Bus_Int1_AddrIn <= Addr_ADC14; end if;
			if(Mem_Addr_Cnt_Out = 15) then Bus_Int1_AddrIn <= Addr_ADC15; end if;
			
			Bus_Int1_DataIn <= ADC_Mem_Ave_M2(conv_integer(Mem_Addr_Cnt_Out(3 downto 0)));
			Mem_Addr_Cnt_INC <= '1';
			Bus_Int1_WE <= '1';
		when others =>
			NS_Bus_Ctrl <= S0;	
	end case;
	end process;
	
	Sync_ADC: process
	begin
	wait until clk_SPI'event and clk_SPI = '1';
	if rst = '0' then CS_ADC_Ctrl <= S0;
	else CS_ADC_Ctrl <= NS_ADC_Ctrl; end if;
	end process;
	
	Sync_Bus: process
	begin
	wait until clk'event and clk = '1';
	if rst = '0' then CS_Bus_Ctrl <= S0;
	else CS_Bus_Ctrl <= NS_Bus_Ctrl; end if;
	end process;
	
	Sync_SPI: process
	begin
	wait until clk'event and clk = '1';
	if rst = '0' then SPI_Dout1_Sync <= '0';
	else SPI_Dout1_Sync <= SPI_Dout; end if;
	end process;
	
	Clk_Div_Top: process
	begin
	wait until clk'event and clk = '1';
	clk_temp2 <= clk_temp2+1;
	clk_SPI <= clk_temp2(2);
	end process;
end Behavioral;
