-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2023 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan a zacina vykonavat program
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------






architecture behavioral of cpu is
  signal PC : std_logic_vector(12 downto 0);
  signal PC_INCR : std_logic;
  signal PC_DECR : std_logic;

  signal PTR : std_logic_vector(12 downto 0);
  signal PTR_INCR: std_logic;
  signal PTR_DECR: std_logic;
  

  signal CNT : std_logic_vector(7 downto 0);
  signal CNT_INCR: std_logic;
  signal CNT_DECR: std_logic;
  signal CNT_SET: std_logic;

  signal mx1_sel : std_logic;
  signal mx2_sel : std_logic_vector(1 downto 0);
  signal CNT_0 : std_logic;

  type fsm_state is (

  IDLE,
  FETCH,
  DECODE,
  S_PTR_INCR,
  S_PTR_DECR,
  S_PC_INCR,
  PC_INCR2,
  S_PC_DECR,
  PC_DECR2,
  S_WHILE,
  S_WHILE2,
  S_WHILE3,
  S_WHILE_END,
  BREAK,
  PRINT,
  PRINT_2,
  S_READ,
  S_RETURN,
  NOOP,
  S_READY,
  IDLE_INIT,
  S_READ_2,
  S_WHILE_END2,
  S_WHILE_END3,
  BREAK2,
  BREAK3
 
  



  );







  signal curr_state : fsm_state := IDLE;
  signal next_state : fsm_state;

begin
  process_pc : process (CLK, RESET)
  begin
    if (RESET = '1') then
      PC <= (others => '0');
    elsif (rising_edge(CLK)) then
      
      if (PC_INCR = '1') then
        PC <= PC + '1';
      elsif (PC_DECR = '1') then
        PC <= PC - '1';
      end if;
    end if;
  end process;

  process_PTR : process (CLK, RESET)
  begin
    if (RESET = '1') then
      PTR <= (others => '0');
    elsif(rising_edge(CLK)) then
     
      if (PTR_INCR = '1') then
        PTR <= PTR + '1';
      elsif(PTR_DECR = '1')then
        PTR <= PTR - '1';
      end if;
    end if;
  end process;

  process_CNT : process(CLK, RESET)
  begin
    if (RESET = '1') then
            CNT <= (others => '0');
    elsif(rising_edge(CLK)) then
      if (CNT_INCR = '1') then
        CNT <= CNT + '1';
      elsif (CNT_SET = '1') then
        CNT <= X"01";
      
      elsif (CNT_DECR = '1') then
                    CNT <= CNT - '1';
      end if;
    end if;
  end process;

  process_CNT_0 : process(CNT)
  begin
    if ( CNT = X"00") then
      CNT_0 <= '1';
    else
      CNT_0 <= '0';
    end if;
  end process;

  process_mx_1 : process(mx1_sel, PC, PTR)
  begin
    case mx1_sel is
      when '0' => DATA_ADDR <= PC;
      when '1' => DATA_ADDR <= PTR;
      when others => null;
    end case;
 end process;
  process_mx_2 : process(mx2_sel, IN_DATA, DATA_RDATA)
  begin
    case mx2_sel is
      when "00" => DATA_WDATA <= IN_DATA;
      when "01" => DATA_WDATA <= DATA_RDATA;
      when "10" => DATA_WDATA <= DATA_RDATA - 1;
      when "11" => DATA_WDATA <= DATA_RDATA + 1;
      when others => null;
    end case;
  end process;

  automata : process(CLK,RESET)
  begin
    if RESET = '1' then
      curr_state <= IDLE;
    elsif rising_edge(CLK) then
      if ( EN = '1') then
        curr_state <= next_state;
      end if;
      
    end if;
  end process;

  automata_next : process(IN_VLD, OUT_BUSY, DATA_RDATA, CNT_0, curr_state, EN, mx1_sel)
  begin
   
 
    
    
    DATA_EN <= '0';
    DATA_RDWR <= '0';
   
  
    IN_REQ <= '0';
    OUT_WE <= '0';
    OUT_DATA <= X"00";
    PC_INCR <= '0';
    PC_DECR <= '0';

    PTR_INCR <= '0';
    PTR_DECR <= '0';

    CNT_INCR <= '0';
    CNT_DECR <= '0';
    mx1_sel <= '0';
    mx2_sel <= "01";
    
    case curr_state is
      
     

      when IDLE =>
        
          
        READY <= '0';
        DONE <= '0'; 
        
             
          DATA_EN <= '1'; 
          mx1_sel <= '1';                         
          if DATA_RDATA = x"40" then
            next_state <= S_READY;
          else
              ptr_incr <= '1';
              next_state <= IDLE;
          end if;
          
        

      
      
         

      when S_READY =>

          DATA_EN <= '0';
          PTR_INCR <= '0';
          READY <= '1';
          next_state <= FETCH;
      
     
            
        
      when FETCH =>
          if( EN = '1') then
            
            PTR_INCR <= '0';
            next_state <= DECODE;
            mx1_sel <= '0';
            DATA_EN <='1';
            DATA_RDWR <= '0';
          end if;
        
          
          
        
              
      
            
        
                
      when DECODE =>

         
          case DATA_RDATA is
            WHEN X"3E" => next_state <= S_PTR_INCR;
            when X"3C" => next_state <= S_PTR_DECR;
            when X"2B" => next_state <= S_PC_INCR;
            when X"2D" => next_state <= S_PC_DECR;
            when X"5B" => next_state <= S_WHILE;
            when X"5D" => next_state <= S_WHILE_END;
            when X"7E" => next_state <= BREAK;
            when X"2E" => next_state <= PRINT;
            when X"2C" => next_state <= S_READ;
            when X"40" => next_state <= S_RETURN;
            when others => next_state <= NOOP;
          end case;

      when S_PC_INCR =>
            PC_INCR <= '1';
            mx1_sel <= '1';
            DATA_RDWR <= '0';
            DATA_EN <= '1';
            next_state <= PC_INCR2;
      when PC_INCR2 =>
            mx1_sel <= '1';
            mx2_sel <= "11";
            DATA_RDWR <= '1';
            DATA_EN <= '1';
            next_state <= FETCH;
      when S_PC_DECR =>
            PC_INCR <= '1';
            MX1_SEL <= '1';
            DATA_RDWR <= '0';
            DATA_EN <= '1';
            next_state <= PC_DECR2;
      when PC_DECR2 =>
            MX1_SEL <= '1';
            MX2_SEL <= "10";
            DATA_RDWR <= '1';
            DATA_EN <= '1';
            next_state <= FETCH;
      when S_PTR_INCR =>
            PC_INCR <= '1';
            PTR_INCR <= '1';
            next_state <= FETCH;
      when S_PTR_DECR =>
            PC_INCR <= '1';
            PTR_DECR <= '1';
            next_state <= FETCH;
      when PRINT =>
            PC_INCR <= '1';
            MX1_SEL <= '1';
            DATA_RDWR <= '0';
            DATA_EN <= '1';
            next_state <= PRINT_2;
      when PRINT_2 =>
        if ( OUT_BUSY = '1') then
          next_state <= PRINT_2;
        else
          OUT_WE <= '1';
          OUT_DATA <= DATA_RDATA;
          next_state <= FETCH;
        end if;
      when S_READ =>
        IN_REQ <= '1';
        if ( IN_VLD = '1') then
          next_state <= S_READ_2;
        else
          next_state <= S_READ;
        end if;
      when S_READ_2 =>
        PC_INCR <= '1';
        MX1_SEL <= '1';
        DATA_RDWR <= '1';
        DATA_EN <= '1';
        MX2_SEL <= "00";
        next_state <= FETCH;    
      when S_WHILE =>
          PC_INCR <= '1';
          MX1_SEL <= '1';
          DATA_RDWR <= '0';
          DATA_EN <= '1';
          next_state <= S_WHILE2;
      when S_WHILE2 =>
          if ( DATA_RDATA = X"00") then
            CNT_SET <= '1';
            MX1_SEL <= '0';
            DATA_RDWR <= '0';
            DATA_EN <= '1';
            next_state <= S_WHILE3;
          else
            next_state <= FETCH;
          end if;
      when S_WHILE3 =>
            pc_incr <= '1';
            if data_rdata = x"5D" then
              next_state <= FETCH;
            else
              next_state <= S_WHILE3;
              data_en <= '1';
            end if;
      when S_WHILE_END =>
              mx1_sel <= '1';
              data_rdwr <= '0';
              data_en <= '1';
              next_state <= S_WHILE_END2;
      when S_while_end2 =>
              if data_rdata = x"00" then
                next_state <= FETCH;
                pc_incr <= '1';
              else
                next_state <= S_WHILE_END3;
                data_en <= '1';

              end if;
      when S_WHILE_END3 =>
      
        if pc = X"00" then
            pc_decr <= '0';
        else
            pc_decr <= '1';
        end if;
        -- [
        if DATA_RDATA = X"5B" then
            next_state <= FETCH;
            pc_incr <= '1';
        else
            next_state <= s_while_end3;
            DATA_EN <= '1';
        end if;

      when BREAK =>
          
        PC_INCR <= '1';
        mx1_sel <= '0';
        DATA_RDWR <= '0';
        data_en <= '1';
        
        next_state <= BREAK2;
        
      when BREAK2 =>
          data_en <= '1';
          if ( data_rdata = x"5D") then
            next_state <= fetch;
          else
            next_state <= BREAK;
            
          end if;

      
          
      
        
      when NOOP =>
        PC_INCR <= '1';
        next_state <= fetch;

      when S_RETURN =>
        DONE <= '1';
        
       

      when others =>
    

   

    end case;
  end process;





 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --      - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --      - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly. 

end behavioral;