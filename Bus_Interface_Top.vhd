Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


library machxo3d;
use machxo3d.all;


library work;
use work.Bus_Interface_Common.all;

entity Bus_Interface_Top is
	Port(
		SCI_RX: in STD_LOGIC;
		SCI_TX: inout STD_LOGIC;
		
		LED_1: out STD_LOGIC;
		LED_2: out STD_LOGIC;
		LED_3: out STD_LOGIC;
		LED_4: out STD_LOGIC;
		LED_5: out STD_LOGIC;
		LED_6: out STD_LOGIC;
		LED_7: out STD_LOGIC;
		LED_8: out STD_LOGIC;
		PWM_Test_Out: out std_logic;
		ADC_SCLK: inout std_logic;
		ADC_DIN: inout std_logic;
		ADC_CSn: out std_logic;
		ADC_DOUT: in std_logic;
		DSP_G1: out std_logic;
		DSP_G2: out std_logic
		);
	end Bus_Interface_Top;
	
architecture Behavioral of Bus_Interface_Top is
	COMPONENT OSCJ
	GENERIC (NOM_FREQ: string := "8.31");
	PORT ( STDBY :IN std_logic;
		OSC :OUT std_logic;
		SEDSTDBY :OUT std_logic
		);
	END COMPONENT;
	
	--Declare PLL
	COMPONENT PLL_Clk
	PORT (
		ClkI: in std_logic;
		ClkOP: out std_logic;
		Lock: out std_logic
		);
	END COMPONENT;
	
	--Declare Bus_Master
	COMPONENT Bus_Master
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		Data : INOUT std_logic_vector(15 downto 0);
		Addr : IN std_logic_vector(15 downto 0);
		Xrqst : IN std_logic;
		XDat : OUT std_logic;
		YDat : IN std_logic;
		BusRqst : IN std_logic_vector(9 downto 0);
		BusCtrl : OUT std_logic_vector(9 downto 0)
	);
	END COMPONENT;
	
	--Declare RS232_Usr_Int
	COMPONENT RS232_Usr_Int
		Generic(
		Baud : integer;
		clk_in : integer
		);
	PORT(
		clk : IN std_logic;
		rst : IN std_logic;
		rs232_rcv : IN std_logic;
		rs232_xmt : OUT std_logic;
		Data : INOUT std_logic_vector(15 downto 0);
		Addr : OUT std_logic_vector(15 downto 0);
		Xrqst : OUT std_logic;
		XDat : IN std_logic;
		YDat : OUT std_logic;
		BusRqst : OUT std_logic;
		BusCtrl : IN std_logic
		);
	END COMPONENT;
	
	COMPONENT LED_Ctrl is 
	PORT(
		clk: in std_logic;
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
		END COMPONENT;
		
	COMPONENT ADC_Int is
	PORT(
		clk: in std_logic;
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
		END COMPONENT;
		
	COMPONENT PI_Buck is
	PORT(
		clk: in std_logic;
		rst: in std_logic;
		Data: inout std_logic_vector(15 downto 0);
		Addr: out std_logic_vector(15 downto 0);
		Xrqst: out std_logic;
		XDat: in std_logic;
		YDat: out std_logic;
		BusRqst: out std_logic;
		BusCtrl: in std_logic
		);
		END COMPONENT;
		
		--Declare Std_Counter Component
	component Std_Counter is
	generic
	(
		Width : integer
	);
	port(INC,rst,clk: in std_logic;
		Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
	end component;
	
	--Signals
	--Declare Signals for Bus Interface
	signal Bus_Int1_WE, Bus_Int1_RE, BUS_Int1_Busy: STD_LOGIC := '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn: STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	
	--Inputs
	signal Addr : std_logic_vector(15 downto 0) := (others => '0');
	signal Xrqst : std_logic := '0';
	signal YDat : std_logic := '0';
	signal BusRqst : std_logic_vector(9 downto 0) := (others => '0');
	signal Data : std_logic_vector(15 downto 0) := (others => '0');
	signal XDat : std_logic := '0';
	signal BusCtrl : std_logic_vector(9 downto 0) := (others => '0');
	
	--Internal Clock
	signal OSC_Stdby, OSC_Out, OSC_SEDSTDBY, clk: std_logic := '0';
	
	--Reset
	signal PLL_Lock, System_rst: std_logic := '0';
	signal Reset_Cnt_INC, Reset_Cnt_rst: std_logic := '0';
	signal Reset_Cnt_out: std_logic_vector(7 downto 0) := (others => '0');
	
	--Misc
	signal LED_En: std_logic := '0';
	signal LED_1n,LED_2n,LED_3n,LED_4n,LED_5n,LED_6n,LED_7n,LED_8n : STD_LOGIC := '0';
	
begin
	--Instantiate Internal Oscillator
	INT_OSC: OSCJ PORT MAP (
		STDBY => OSC_Stdby,
		OSC => OSC_Out,
		SEDSTDBY => OSC_SEDSTDBY
	);
	
	
	--Instantiate PLL
	PLL_1: PLL_Clk PORT MAP (
		ClkI => OSC_Out,
		ClkOP => clk,
		Lock => PLL_Lock
	);
	
	
	--Instantiate Bus_Master
	BM : Bus_Master PORT MAP (
		clk => clk,
		rst => System_rst,
		Data => Data,
		Addr => Addr,
		Xrqst => Xrqst,
		XDat => XDat,
		YDat => YDat,
		BusRqst => BusRqst,
		BusCtrl => BusCtrl
	);
	
	
	--Instantiate RS232_Usr_Int
	RS232_Usr: RS232_Usr_Int
	Generic Map
	(
		Baud => 9600,
		Clk_In => Clk_Freq
	)
	PORT MAP (
		clk => clk,
		rst => System_rst,
		rs232_rcv => SCI_RX,
		rs232_xmt => SCI_TX,
		Data => Data,
		Addr => Addr,
		Xrqst => Xrqst,
		XDat => XDat,
		YDat => YDat,
		BusRqst => BusRqst(3),
		BusCtrl => BusCtrl(3)
	);
	
	LED_Ctrl1: LED_Ctrl PORT MAP(
			clk => clk,
			rst => System_rst,
			Data => Data,
			Addr => Addr,
			Xrqst => Xrqst,
			XDat => XDat,
			YDat => YDat,
			BusRqst => BusRqst(0),
			BusCtrl => BusCtrl(0),
			LED_En => LED_En,
			LED1_Out => LED_1n,
			LED2_Out => LED_2n,
			LED3_Out => LED_3n,
			LED4_Out => LED_4n,
			LED5_Out => LED_5n,
			LED6_Out => LED_6n,
			LED7_Out => LED_7n,
			LED8_Out => LED_8n
	);
	
	ADC_Int1: ADC_Int PORT MAP(
			clk => clk,
			rst => System_rst,
			SPI_Sclk => ADC_SCLK,
			SPI_Din => ADC_DIN,
			SPI_CSn => ADC_CSn,
			SPI_Dout => ADC_DOUT,
			Data => Data,
			Addr => Addr,
			Xrqst => Xrqst,
			XDat => XDat,
			YDat => YDat,
			BusRqst => BusRqst(1),
			BusCtrl => BusCtrl(1)
			);
	PI_Buck1: PI_Buck PORT MAP(
			clk => clk,
			rst => System_rst,
			Data => Data,
			Addr => Addr,
			Xrqst => Xrqst,
			XDat => XDat,
			YDat => YDat,
			BusRqst => BusRqst(2),
			BusCtrl => BusCtrl(2)
			);
	--Instantiate Reset_Cnt_8
	Reset_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map(
		clk => OSC_Out,
		rst => Reset_Cnt_rst,
		INC => Reset_Cnt_INC,
		Count => Reset_Cnt_Out
	);
	
	
	
	--Oscillator
	OSC_Stdby <= '0';
	
	
	--Tie unused ports to '0'
	BusRqst(9 downto 4) <= (others => '0');
	--DSP_G1 <= '0';
	DSP_G2 <= '0';
	
	--Reset Block1
	Reset_Blk1: process
	begin
		wait until OSC_Out'event and OSC_Out = '1';
			if(PLL_Lock = '0') then
				Reset_Cnt_rst <= '0';
			else
				Reset_Cnt_rst <= '1';
			end if;
	end process;
	
	--Reset Block
	Reset_Blk: process
	begin
		wait until OSC_Out'event and OSC_Out = '1';
			if(Reset_Cnt_out < X"7F") then
				System_rst <= '0';
				Reset_Cnt_Inc <= '1';
			else
				System_rst <= '1';
				Reset_Cnt_Inc <= '0';
			end if;
	end process;
	
	LED_Invert: process(LED_1n, LED_2n, LED_3n, LED_4n, LED_5n, LED_6n, LED_7n, LED_8n, SCI_RX, SCI_TX)
	begin
		LED_8 <= not(SCI_TX);
		LED_7 <= not(SCI_RX);
		LED_6 <= not(LED_6n);
		LED_5 <= not(LED_5n);
		LED_4 <= not(LED_4n);
		LED_3 <= not(LED_3n);
		LED_2 <= not(LED_2n);
		LED_1 <= not(LED_1n);
		PWM_Test_Out <= LED_1n;
		DSP_G1 <= LED_1n;
	end process;
end Behavioral;
		
		