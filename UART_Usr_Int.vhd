library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

library work;
use work.Bus_Interface_Common.all;

entity RS232_Usr_Int is
	generic(Baud: integer := 9600;
	clk_in: integer := 25000000);
	
	Port(
		clk: in std_logic;
		rst: in std_logic;
		rs232_rcv: in std_logic;
		rs232_xmt: OUT std_logic;
		Data: inout std_logic_vector(15 downto 0);
		Addr: out std_logic_vector(15 downto 0);
		Xrqst: out std_logic;
		XDat: in std_logic;
		YDat: out std_logic;
		BusRqst: out std_logic;
		BusCtrl: in std_logic
	);
end RS232_Usr_Int;
	
architecture Behavioral of RS232_Usr_Int is
	type state_type is (S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, S21, S22, S23, S24, S25, S26, S27, S28, S29, S30, S31, S32, S33, S34, S35, S36);
	signal CS_RS232_R, NS_RS232_R, CS_RS232_W, NS_RS232_W, CS_FIFO_Bus, NS_FIFO_Bus: state_type;
	signal rx_done, tx_done: STD_LOGIC:= '0';
	signal temp_rcv: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');
	signal i, j: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');
	signal uartclk: STD_LOGIC := '0';
	signal u: integer;
	signal rs232_rcv_s, rs232_rcv_t: STD_LOGIC := '1';
	signal txbuff: STD_LOGIC_VECTOR(9 downto 0) := (others => '1');
	
	signal STD_FIFO_R_WriteEn, STD_FIFO_R_ReadEn: STD_LOGIC := '0';
	signal STD_FIFO_R_Empty, STD_FIFO_R_Full: STD_LOGIC := '0';
	signal STD_FIFO_R_DataIn, STD_FIFO_R_DataOut: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	signal STD_FIFO_W_WriteEn, STD_FIFO_W_ReadEn: STD_LOGIC := '0';
	signal STD_FIFO_W_Empty, STD_FIFO_W_Full: STD_LOGIC := '0';
	signal STD_FIFO_W_DataIn, STD_FIFO_W_DataOut: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy : STD_LOGIC:= '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	
	signal LD_busy, LD_busy2, LD_rx, LD_tx, LD_temp_data, LD_temp2: STD_LOGIC := '0';
	signal LD_Temp_Addr_High, LD_Temp_Addr_Low, LD_Temp_Data_High, LD_Temp_Data_Low, ld_temp_cmd: STD_LOGIC := '0';
	signal LD_Pkt_Len, LD_Chk_Sum, LD_Base_Addr : STD_LOGIC:= '0';
	signal LD_Reg_Addr_H, LD_Reg_Addr_L, LD_Reg_Cnt, LD_Reg_Addr : STD_LOGIC := '0';
	signal LD_Data_Temp_H, LD_Data_Temp_L: STD_LOGIC := '0';
	
	signal busy, busy_reg_o, busy2, busy2_reg_o, rx, rx_reg_o, tx, tx_reg_o: STD_LOGIC := '0';
	signal temp_data_reg_o, temp_data: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal temp2_reg_o, temp2: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	signal Temp_Addr_High_reg_o, Temp_Addr_High, Temp_Addr_Low_reg_o, Temp_Addr_Low,Temp_Cmd_reg_o, Temp_Cmd,Temp_Data_High_reg_o, Temp_Data_High, Temp_Data_Low_reg_o, Temp_Data_Low, Pkt_Len_reg_o, Pkt_Len : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	signal Chk_Sum_reg_o, Chk_Sum, Base_Addr_reg_o, Base_Addr, Reg_Addr_reg_o, Reg_Addr: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal Reg_Addr_H_reg_o, Reg_Addr_H, Reg_Addr_L_reg_o, Reg_Addr_L, Reg_Cnt_reg_o, Reg_Cnt, Data_Temp_H_reg_o, Data_Temp_H, Data_Temp_L_reg_o, Data_Temp_L: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	signal Rcv_Cnt_rst, Rcv_Cnt_INC: STD_LOGIC := '0';
	signal Buf_Cnt_rst, Buf_Cnt_INC: STD_LOGIC := '0';
	signal Reg_Cnt_rst, Reg_Cnt_INC: STD_LOGIC := '0';
	signal Rcv_Cnt_Out, Buf_Cnt_Out, Reg_Cnt_Out : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	type ram_type is array (0 to (2**8)-1) of std_logic_vector(7 downto 0);
	signal RAM: ram_type;
	signal RAM_wea: STD_LOGIC := '0';
	signal RAM_address, RAM_Data_In, RAM_Data_Out: STD_LOGIC_VECTOR(7 downto 0);
	
	constant CM: integer := clk_in/Baud;
	constant CN: integer := CM/2;
	
	COMPONENT STD_FIFO 
	Generic (
		DATA_WIDTH 		: integer ;		-- Width of FIFO
		FIFO_DEPTH 		: integer ;	--	Depth of FIFO
		FIFO_ADDR_LEN  : integer		-- Required number of bits to represent FIFO_Depth
	);
	Port ( 
		CLK     : in  STD_LOGIC;                                       -- Clock input
		RST     : in  STD_LOGIC;                                       -- Active low reset
		WriteEn : in  STD_LOGIC;                                       -- Write enable signal
		DataIn  : in  STD_LOGIC_VECTOR (7 downto 0);      -- Data input bus
		ReadEn  : in  STD_LOGIC;                                       -- Read enable signal
		DataOut : out STD_LOGIC_VECTOR (7 downto 0);      -- Data output bus
		Empty   : out STD_LOGIC;                                       -- FIFO empty flag
		Full    : out STD_LOGIC                                        -- FIFO full flag
	);
	end COMPONENT;
	
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
	
	COMPONENT Std_Counter is
	generic( Width: integer);
	port(INC,rst,clk: in std_logic;
	Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
	end COMPONENT;
	
	begin
	STD_FIFO_R: STD_FIFO
	Generic Map
	( DATA_WIDTH => 8, 
	FIFO_DEPTH => 512, 
	FIFO_ADDR_LEN => 9
	)
	Port Map
	(
		CLK => clk,
		RST => rst,
		WriteEn => STD_FIFO_R_WriteEn,
		DataIn => STD_FIFO_R_DataIn,
		ReadEn => STD_FIFO_R_ReadEn,
		DataOut => STD_FIFO_R_DataOut,
		Empty => STD_FIFO_R_Empty,
		Full => STD_FIFO_R_Full
	);
	
	STD_FIFO_W: STD_FIFO
	Generic Map
	( DATA_WIDTH => 8, 
	FIFO_DEPTH => 512, 
	FIFO_ADDR_LEN => 9
	)
	Port Map
	(
		CLK => clk,
		RST => rst,
		WriteEn => STD_FIFO_W_WriteEn,
		DataIn => STD_FIFO_W_DataIn,
		ReadEn => STD_FIFO_W_ReadEn,
		DataOut => STD_FIFO_W_DataOut,
		Empty => STD_FIFO_W_Empty,
		Full => STD_FIFO_W_Full
	);
	
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
	
	Rcv_Cnt: Std_Counter
	generic map( Width => 8)
	Port Map(
	clk => clk,
	rst => Rcv_Cnt_rst,
	INC => Rcv_Cnt_INC,
	Count => Rcv_Cnt_Out
	);
	
	Buf_Cnt: Std_Counter
	generic map( Width => 8)
	Port Map(
	clk => clk,
	rst => Buf_Cnt_rst,
	INC => Buf_Cnt_INC,
	Count => Buf_Cnt_Out
	);
	
	Reg_Cnt1: Std_Counter
	generic map( Width => 8)
	Port Map(
	clk => clk,
	rst => Reg_Cnt_rst,
	INC => Reg_Cnt_INC,
	Count => Reg_Cnt_Out
	);
	
	Reg_Proc: process
	begin
	wait until clk'event and clk ='1';
	if rst = '0' then
		busy_reg_o <= '0';
		busy2_reg_o <= '0';
		rx_reg_o <= '0';
		tx_reg_o <= '0';
		temp_data_reg_o <= (others => '0');
		temp2_reg_o <= (others => '0');
		Temp_Addr_High_reg_o <= (others => '0');
		Temp_Addr_Low_reg_o <= (others => '0');
		Temp_Data_High_reg_o <= (others => '0');
		Temp_Data_Low_reg_o <= (others => '0');
		Temp_Cmd_reg_o <= (others => '0');
		Pkt_Len_reg_o <= (others => '0');
		Chk_Sum_reg_o <= (others => '0');
		Reg_Addr_H_reg_o <= (others => '0');
		Reg_Addr_L_reg_o <= (others => '0');
		Reg_Addr_reg_o <= (others => '0');
		Data_Temp_H_reg_o <= (others => '0');
		Data_Temp_L_reg_o <= (others => '0');
		Reg_Cnt_reg_o <= (others => '0');
		Base_Addr_reg_o <= (others => '0');
	else
		if (LD_busy = '1') then busy_reg_o <= busy; end if;
		if (LD_busy2 = '1') then busy2_reg_o <= busy2; end if;
		if (LD_rx = '1') then rx_reg_o <= rx; end if;
		if (LD_tx = '1') then tx_reg_o <= tx; end if;
		if (LD_temp_data = '1') then temp_data_reg_o <= temp_data; end if;
		if (LD_temp2 = '1') then temp2_reg_o <= temp2; end if;
		if (LD_Temp_Addr_High = '1') then Temp_Addr_High_reg_o <= Temp_Addr_High; end if;
		if (LD_Temp_Addr_Low = '1') then Temp_Addr_Low_reg_o <= Temp_Addr_Low; end if;
		if (LD_Temp_Data_High = '1') then Temp_Data_High_reg_o <= Temp_Data_High; end if;
		if (LD_Temp_Data_Low = '1') then Temp_Data_Low_reg_o <= Temp_Data_Low; end if;
		if (LD_Temp_Cmd = '1') then Temp_Cmd_reg_o <= Temp_Cmd; end if;
		if (LD_Pkt_Len = '1') then Pkt_Len_reg_o <= Pkt_Len; end if;
		if (LD_Chk_Sum = '1') then Chk_Sum_reg_o <= Chk_Sum; end if;
		if (LD_Reg_Addr_H = '1') then Reg_Addr_H_reg_o <= Reg_Addr_H; end if;
		if (LD_Reg_Addr_L = '1') then Reg_Addr_L_reg_o <= Reg_Addr_L; end if;
		if (LD_Reg_Addr = '1') then Reg_Addr_reg_o <= Reg_Addr; end if;
		if (LD_Data_Temp_H = '1') then Data_Temp_H_reg_o <= Data_Temp_H; end if;
		if (LD_Data_Temp_L = '1') then Data_Temp_L_reg_o <= Data_Temp_L; end if;
		if (LD_Reg_Cnt = '1') then Reg_Cnt_reg_o <= Reg_Cnt; end if;
		if (LD_Base_Addr = '1') then Base_Addr_reg_o <= Base_Addr; end if;
	end if;
	end process;
	
	Ram_Proc: process
	begin
	wait until clk'event and clk = '1';
	if (RAM_wea = '1') then
		RAM(conv_integer(RAM_address)) <= RAM_Data_In;
	end if;
	RAM_Data_Out <= RAM(conv_integer(RAM_address));
	end process;
	
	NSL_RS232_R: process(CS_RS232_R, rs232_rcv_s, rx_done, STD_FIFO_R_FULL, temp_rcv)
	begin
		busy  <= '0';
		rx <= '0';
		NS_RS232_R <= S0;
		LD_busy <= '0';
		LD_rx <= '0';
		
		STD_FIFO_R_WriteEn <= '0';
		STD_FIFO_R_DataIn <= (others => '0');
		
		case CS_RS232_R is
			when S0 =>
				if(rs232_rcv_s = '1') then NS_RS232_R <= S0;
				else NS_RS232_R <= S1; end if;
				busy  <= '0';
				rx <= '0';
				LD_busy <= '1';
				LD_rx <= '1';
			when S1 =>
				NS_RS232_R <= S2;
				busy  <= '1';
				rx <= '1';
				LD_busy <= '1';
				LD_rx <= '1';
			when S2 =>
				if(rx_done = '0') then NS_RS232_R <= S2;
				else NS_RS232_R <= S3; end if;
			when S3 =>
				if(STD_FIFO_R_Full = '0') then
					STD_FIFO_R_DataIn <= temp_rcv;
					STD_FIFO_R_WriteEn <= '1';
				end if;
				NS_RS232_R <= S0;
			when others =>
				NS_RS232_R <= S0;
			
			end case;
	end process; 
	
	NSL_RS232_W: process(CS_RS232_W, tx_done, STD_FIFO_W_Empty, STD_FIFO_W_DataOut)
	begin
		tx <= '0';
		NS_RS232_W <= S0;
		temp2 <= (others => '0');
		LD_tx <= '0';
		LD_temp2 <= '0';
		Busy2 <= '0';
		LD_Busy2 <= '0';
		STD_FIFO_W_ReadEn <= '0';
		
		case CS_RS232_W is
			when S0 =>
				if(STD_FIFO_W_Empty = '1') then NS_RS232_W <= S0;
				else NS_RS232_W <= S1; STD_FIFO_W_ReadEn <= '1'; end if;
				busy2 <= '0';
				tx <= '0';
				LD_tx <= '1';
				LD_busy2 <= '1';
			when S1 =>
				temp2 <= STD_FIFO_W_DataOut;
				LD_temp2 <= '1';
				NS_RS232_W <= S2;
			when S2 =>
				busy2 <= '1';
				tx <= '1';
				LD_tx <= '1';
				LD_busy2 <= '1';
				NS_RS232_W <= S3;
			when S3 =>
				if(tx_done = '0') then NS_RS232_W <= S3;
				else NS_RS232_W <= S0; end if;
			when others =>
				NS_RS232_W <= S0;
			end case;
				
	end process;
	
	NSL_FIFO_Bus: process(CS_FIFO_Bus, STD_FIFO_R_Empty, Temp_Cmd_reg_o, Bus_Int1_Busy, STD_FIFO_R_DataOut, Temp_Addr_High_reg_o, Temp_Addr_Low_reg_o, Temp_Data_High_reg_o, Temp_Data_Low_reg_o, Temp_Data_reg_o, Bus_Int1_DataOut, temp_data_reg_o, Pkt_Len_reg_o, Chk_Sum_reg_o, Rcv_Cnt_Out, RAM_Data_Out, Reg_Cnt_reg_o, Reg_Addr_H_reg_o, Reg_Addr_L_reg_o, Base_Addr_reg_o)
	begin
		NS_FIFO_Bus <= S0;
		Temp_Cmd <= (others => '0');
		LD_Temp_Cmd <= '0';
		Temp_Addr_High <= (others => '0');
		LD_Temp_Addr_High <= '0';
		Temp_Addr_Low <= (others => '0');
		LD_Temp_Addr_Low <= '0';
		Bus_Int1_AddrIn <= (others => '0');
		Bus_Int1_RE <= '0';
		Bus_Int1_DataIn <= (others => '0');
		Bus_Int1_WE <= '0';
		Temp_Data <= (others => '0');
		LD_Temp_Data <= '0';
		Temp_Data_High <= (others => '0');
		LD_Temp_Data_High <= '0';
		Temp_Data_Low <= (others => '0');
		LD_Temp_Data_Low <= '0';
		
		STD_FIFO_R_ReadEn <= '0';
		STD_FIFO_W_DataIn <= (others => '0');
		STD_FIFO_W_WriteEn <= '0';
		
		Rcv_Cnt_rst <= '1';
		Rcv_Cnt_INC <= '0';
		Buf_Cnt_rst <= '1';
		Buf_Cnt_INC <= '0';
		Reg_Cnt_rst <= '1';
		Reg_Cnt_INC <= '0';
		
		RAM_address <= (others => '0');
		RAM_Data_In <= (others => '0');
		RAM_wea <= '0';
		
		Pkt_Len <= (others => '0');
		Chk_Sum <= (others => '0');
		LD_Pkt_Len <= '0';
		LD_Chk_Sum <= '0';
		
		Reg_Addr_H <= (others => '0');
		LD_Reg_Addr_H <= '0';
		Reg_Addr_L <= (others => '0');
		LD_Reg_Addr_L <= '0';
		Reg_Addr <= (others => '0');
		LD_Reg_Addr <= '0';
		Data_Temp_H <= (others => '0');
		LD_Data_Temp_H <= '0';
		Data_Temp_L <= (others => '0');
		LD_Data_Temp_L <= '0';
		Reg_Cnt <= (others => '0');
		LD_Reg_Cnt <= '0';
		Base_Addr <= (others => '0');
		LD_Base_Addr <= '0';
		
		case CS_FIFO_Bus is
			when S0 =>
				if(STD_FIFO_R_Empty = '1') then NS_FIFO_Bus <= S0;
				else NS_FIFO_Bus <= S1; STD_FIFO_R_ReadEn <= '1'; end if;
				Rcv_Cnt_rst  <= '0';
				Buf_Cnt_rst  <= '0';
				Reg_Cnt_rst  <= '0';
			when S1 =>
				Temp_Cmd <= STD_FIFO_R_DataOut;
				LD_Temp_Cmd <= '1';
				NS_FIFO_Bus <= S2;
			when S2 => 
				if(Temp_Cmd_reg_o = X"7E") then NS_FIFO_Bus <= S3;
				else NS_FIFO_Bus <= S0; end if;
			when S3 =>
				if(STD_FIFO_R_Empty = '1') then NS_FIFO_Bus <= S3; 
				else NS_FIFO_Bus <= S4; STD_FIFO_R_ReadEn <= '1'; end if;
			when S4 =>
				Pkt_Len <= STD_FIFO_R_DataOut;
				LD_Pkt_Len <= '1';
				NS_FIFO_Bus <= S5;
			when S5 =>
				if((Pkt_Len_reg_o < X"FF") and (Pkt_Len_reg_o > X"03")) then 
					NS_FIFO_Bus <= S6;
				else NS_FIFO_Bus <= S0; end if;
				Chk_Sum <= X"0000";
				LD_Chk_Sum <= '1';
				Rcv_Cnt_rst <= '0';
			when S6 =>
				if(Rcv_Cnt_Out < (Pkt_Len_reg_o+1)) then NS_FIFO_Bus <= S7;
				else NS_FIFO_Bus <= S9; end if;
			when S7 =>
				if(STD_FIFO_R_Empty	= '1') then NS_FIFO_Bus <= S7;
				else NS_FIFO_Bus <= S8; STD_FIFO_R_ReadEn <= '1'; end if;
			when S8 =>
				if(Rcv_Cnt_Out < Pkt_Len_reg_o) then LD_Chk_Sum <= '1'; end if;
				RAM_Data_In <= STD_FIFO_R_DataOut;
				RAM_address <= Rcv_Cnt_Out;
				RAM_wea <= '1';
				Chk_Sum <= Chk_Sum_reg_o + STD_FIFO_R_DataOut;
				Temp_Cmd <= STD_FIFO_R_DataOut;
				LD_Temp_Cmd <= '1';
				Rcv_Cnt_INC <= '1';
				NS_FIFO_Bus <= S6;
			when S9 =>
				if((X"FF"-Chk_Sum_reg_o(7 downto 0)) = Temp_Cmd_reg_o) then NS_FIFO_Bus <= S10;
				else NS_FIFO_Bus <= S0; end if;
				Rcv_Cnt_rst <= '0';
				RAM_address <= X"01";
			when S10 =>
				Reg_Cnt <= RAM_Data_Out;
				LD_Reg_Cnt <= '1';
				RAM_address <= X"01";
				NS_FIFO_Bus <= S11;
			when S11 =>
				RAM_address <= X"02";
				NS_FIFO_Bus <= S12;
			when S12 =>
				Reg_Addr_H <= RAM_Data_Out;
				LD_Reg_Addr_H <= '1';
				RAM_address <= X"02";
				NS_FIFO_Bus <= S13;
			when S13 =>
				RAM_address <= X"03";
				NS_FIFO_Bus <= S14;
			when S14 =>
				Reg_Addr_L <= RAM_Data_Out;
				LD_Reg_Addr_L <= '1';
				RAM_address <= X"03";
				NS_FIFO_Bus <= S15;	
			when S15 =>
				Base_Addr(15 downto 8) <= Reg_Addr_H_reg_o;
				Base_Addr(7 downto 0) <= Reg_Addr_L_reg_o;
				LD_Base_Addr <= '1';
				RAM_address <= X"00";
				NS_FIFO_Bus <= S16;
			when S16 =>
				if(RAM_Data_Out = X"0F") then NS_FIFO_Bus <= S17;
				elsif(RAM_Data_Out = X"0A") then NS_FIFO_Bus <= S28;
				else NS_FIFO_Bus <= S0; end if;
				RAM_address <= X"00";
				Rcv_Cnt_rst <= '0';
			when S17 =>
				STD_FIFO_W_DataIn <= X"7E";
				STD_FIFO_W_WriteEn <= '1';
				Chk_Sum <= X"00FF";
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus <= S18;
			when S18 =>
				STD_FIFO_W_DataIn <= ((Reg_Cnt_reg_o(7 downto 0) + Reg_Cnt_reg_o(7 downto 0)) +4);
				STD_FIFO_W_WriteEn <= '1';
				NS_FIFO_Bus <= S19;
			when S19 =>
				STD_FIFO_W_DataIn <= X"0A";
				STD_FIFO_W_WriteEn <= '1';
				Chk_Sum <= Chk_Sum_reg_o - X"0A";
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus <= S20;
			when S20 =>
				STD_FIFO_W_DataIn <= Reg_Cnt_reg_o;
				STD_FIFO_W_WriteEn <= '1';
				Chk_Sum <= Chk_Sum_reg_o - Reg_Cnt_reg_o;
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus <= S21;
			when S21 =>
				STD_FIFO_W_DataIn <= Reg_Addr_H_reg_o;
				STD_FIFO_W_WriteEn <= '1';
				Chk_Sum <= Chk_Sum_reg_o - Reg_Addr_H_reg_o;
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus <= S22;
			when S22 =>
				STD_FIFO_W_DataIn <= Reg_Addr_L_reg_o;
				STD_FIFO_W_WriteEn <= '1';
				Chk_Sum <= Chk_Sum_reg_o - Reg_Addr_L_reg_o;
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus <= S23;
			when S23 =>
				if(Rcv_Cnt_Out < Reg_Cnt_reg_o) then
					Bus_Int1_AddrIn <= Base_Addr_reg_o + Rcv_Cnt_Out;
					Bus_Int1_RE <= '1';
					NS_FIFO_Bus <= S24;
				else NS_FIFO_Bus <= S27; end if;
			when S24 =>
				if(Bus_Int1_Busy = '1') then NS_FIFO_Bus <= S24;
				else NS_FIFO_Bus <= S25; end if;
				Temp_Data <= Bus_Int1_DataOut;
				LD_Temp_Data <= '1';
			when S25 =>
				STD_FIFO_W_DataIn <= Temp_Data_reg_o(15 downto 8);
				STD_FIFO_W_WriteEn <= '1';
				Chk_Sum <= Chk_Sum_reg_o - Temp_Data_reg_o(15 downto 8);
				LD_Chk_Sum <= '1';
				NS_FIFO_Bus <= S26;
			when S26 =>
				STD_FIFO_W_DataIn <= Temp_Data_reg_o(7 downto 0);
				STD_FIFO_W_WriteEn <= '1';
				Chk_Sum <= Chk_Sum_reg_o - Temp_Data_reg_o(7 downto 0);
				LD_Chk_Sum <= '1';
				Rcv_Cnt_INC <= '1';
				NS_FIFO_Bus <= S23;
			when S27 =>
				STD_FIFO_W_DataIn <= Chk_Sum_reg_o(7 downto 0);
				STD_FIFO_W_WriteEn <= '1';
				NS_FIFO_Bus <= S0;
			when S28 =>
				if(Rcv_Cnt_Out < Reg_Cnt_reg_o) then NS_FIFO_Bus <= S29;
				else NS_FIFO_Bus <= S0; end if;
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out +4;
			when S29 =>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out +4;
				Temp_Data_High <= Ram_Data_Out;
				NS_FIFO_Bus <= S30;
			when S30 =>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out +4;
				Temp_Data_High <= Ram_Data_Out;
				LD_Temp_Data_High <= '1';
				NS_FIFO_Bus <= S31;
			when S31 =>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out +5;
				NS_FIFO_Bus <= S32;
			when S32 =>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out +5;
				Temp_Data_Low <= Ram_Data_Out;
				NS_FIFO_Bus <= S33;
			when S33 =>
				RAM_address <= Rcv_Cnt_Out + Rcv_Cnt_Out +5;
				Temp_Data_Low <= Ram_Data_Out;
				LD_Temp_Data_Low <= '1';
				NS_FIFO_Bus <= S34;
			when S34 =>
				NS_FIFO_Bus <= S35;
			when S35 =>
				Bus_Int1_AddrIn <= Base_Addr_reg_o + Rcv_Cnt_Out;
				Bus_Int1_DataIn(15 downto 8) <= Temp_Data_High_reg_o;
				Bus_Int1_DataIn(7 downto 0) <= Temp_Data_Low_reg_o;
				Bus_Int1_WE <= '1';
				NS_FIFO_Bus <= S36;
			when S36 =>
				if Bus_Int1_Busy = '1' then NS_FIFO_Bus <= S36;
				else Rcv_Cnt_INC <= '1'; NS_FIFO_Bus <= S28; end if;
			when others =>
				NS_FIFO_Bus <= S0;
		end case;
	end process;
	
	UART_Clk: process
	begin
		wait until clk'event and clk = '1';
		rs232_rcv_t <= rs232_rcv;
		rs232_rcv_s <= rs232_rcv_t;
		
		if( rst = '0' or (busy_reg_o = '0' and busy2_reg_o = '0')) then
			uartclk <= '0';
			i <= CONV_STD_LOGIC_VECTOR(CN, 16);
		elsif( i = CM) then
			uartclk <= '1';
			i <= X"0000";
		else
			i <= i+1;
			uartclk <= '0';
		end if;
	end process;
	
	UART_Read: process
	begin
	wait until clk'event and clk = '1';
	if rst = '0' or rx_reg_o = '0' then
		temp_rcv <= x"00";
		j <= x"0000";
		rx_done <= '0';
	elsif rx_reg_o = '1' then
		if uartclk = '1' then
			if j< x"09" then
				temp_rcv(7)<=rs232_rcv_s;
				temp_rcv(6 downto 0) <= temp_rcv(7 downto 1);
				j<= j+1;
				rx_done <= '0';
			else
				j <= X"0000";
				rx_done <= '1';
			end if;
		else
			rx_done <= '0';
		end if;
	end if; 
	end process;
	
	UART_Xmit: process
	begin
	wait until clk'event and clk = '1';
	if (rst = '0' or tx_reg_o = '0') then
		rs232_xmt <= '1';
		tx_done <= '0';
		u <= 0;
		
		txbuff(9) <= '1';
		txbuff(8 downto 1) <= temp2_reg_o;
		txbuff(0) <= '0';
	else
		if uartclk = '1' then
			if(u < 10) then 
				rs232_xmt <= txbuff(0);
				txbuff(8 downto 0) <= txbuff(9 downto 1);
				tx_done <= '0';
				u <= u+1;
			else
				u <= 0;
				tx_done <= '1';
			end if;
		end if;
	end if;
	end process;
	
	Sync_States: process
	begin
	wait until clk'event and clk='1';
	if rst = '0'then
		CS_RS232_R <= S0;
		CS_RS232_W <= S0;
		CS_FIFO_BUS <= S0;
	else
		CS_RS232_R <= NS_RS232_R;
		CS_RS232_W <= NS_RS232_W;
		CS_FIFO_BUS <= NS_FIFO_Bus;
	end if;
	end process;
	end Behavioral;
	

