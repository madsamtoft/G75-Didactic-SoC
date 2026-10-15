/*
  Contributors:
    * Dovydas Liutkus (dovli@dtu.dk)
  Description:
    * pixel_acc - STUDENT MODULE (VHDL version)
    * Drop-in VHDL equivalent of pixel_acc.sv. Instantiated by the
    * SystemVerilog wrapper pixel_acc_vhd_wrapper.sv (module pixel_acc).
    *
    * You are given direct read access to ibuf and write access
    * to obuf. Both are synchronous BRAMs with 1-cycle read latency.
    *
    * Interface:
    *   start  - pulsed high for 1 cycle to begin processing
    *   finish - assert high for 1 cycle when all output words
    *            have been written to obuf
    *
    * ibuf read port:
    *   Set ibuf_rd_en='1' and ibuf_rd_addr to the word you want.
    *   ibuf_rd_data is valid on the NEXT clock cycle.
    *
    * obuf write port:
    *   Set obuf_wr_en='1', obuf_wr_addr, obuf_wr_data on the same cycle.
    *   The word is written on the rising edge.
    *
    * Generics:
    *   BUF_AW    - address width (ibuf/obuf have 2^BUF_AW words)
    *   BUF_DEPTH - total number of words in each buffer
    *   IMG_WIDTH - frame width in words (= pixels per row / 4)
    *
    * NOTE: VHDL-2008 (vcom -2008). Entity name differs from pixel_acc
    * so it can share a library with the SystemVerilog wrapper.
*/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pixel_acc_vhd is
  generic (
    BUF_AW    : integer := 15;
    BUF_DEPTH : integer := 25344;
    IMG_WIDTH : integer := 88       -- 352 pixels / 4 pixels-per-word
  );
  port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;

    -- ibuf read port
    ibuf_rd_en   : out std_logic;
    ibuf_rd_addr : out std_logic_vector(BUF_AW-1 downto 0);
    ibuf_rd_data : in  std_logic_vector(31 downto 0);

    -- obuf write port
    obuf_wr_en   : out std_logic;
    obuf_wr_addr : out std_logic_vector(BUF_AW-1 downto 0);
    obuf_wr_data : out std_logic_vector(31 downto 0);

    -- handshake
    start        : in  std_logic;
    finish       : out std_logic
  );
end entity pixel_acc_vhd;

architecture rtl of pixel_acc_vhd is

  -- ============================================================
  -- BRAM has 1-cycle read latency, so:
  --   cycle 0: read ibuf[0] issued  (rd_data not yet valid)
  --   cycle 1: read ibuf[1] issued, ibuf[0] data valid -> write obuf[0]
  --   ...
  --   cycle N: read ibuf[N] issued (last), write obuf[N-1]
  --   cycle N+1: no new read, write obuf[N], assert finish
  --
  -- ============================================================

  type state_t is (IDLE, PROCESS_ST, DRAIN);  -- PROCESS is a VHDL keyword

  signal state      : state_t;
  signal rd_addr    : unsigned(BUF_AW-1 downto 0);  -- current ibuf read address
  signal wr_addr    : unsigned(BUF_AW-1 downto 0);  -- current obuf write address (= rd_addr delayed 1 cycle)
  signal pipe_valid : std_logic;                    -- '0' on first PROCESS cycle (rd_data not yet valid)
  signal pixel_out  : std_logic_vector(31 downto 0);

begin

  -- ---- FSM ----
  fsm : process (clk, rst_n)
  begin
    if rst_n = '0' then
      state      <= IDLE;
      rd_addr    <= (others => '0');
      wr_addr    <= (others => '0');
      pipe_valid <= '0';
      ibuf_rd_en <= '0';
      obuf_wr_en <= '0';
      finish     <= '0';
    elsif rising_edge(clk) then
      ibuf_rd_en <= '0';
      obuf_wr_en <= '0';
      finish     <= '0';

      case state is
        when IDLE =>
          pipe_valid <= '0';
          if start = '1' then
            rd_addr      <= (others => '0');
            ibuf_rd_en   <= '1';
            ibuf_rd_addr <= (others => '0');
            state        <= PROCESS_ST;
          end if;

        when PROCESS_ST =>
          pipe_valid <= '1';
          wr_addr    <= rd_addr;  -- write address tracks read address with 1 cycle latency

          -- Write result from previous read (suppressed on first cycle)
          if pipe_valid = '1' then
            obuf_wr_en   <= '1';
            obuf_wr_addr <= std_logic_vector(wr_addr);
            obuf_wr_data <= pixel_out;
          end if;

          if rd_addr = to_unsigned(BUF_DEPTH - 1, BUF_AW) then
            -- Last read issued - drain the pipeline
            ibuf_rd_en <= '0';
            state      <= DRAIN;
          else
            rd_addr      <= rd_addr + 1;
            ibuf_rd_en   <= '1';
            ibuf_rd_addr <= std_logic_vector(rd_addr + 1);
          end if;

        when DRAIN =>
          -- Write the last word (pipeline had one word in flight)
          obuf_wr_en   <= '1';
          obuf_wr_addr <= std_logic_vector(wr_addr);
          obuf_wr_data <= pixel_out;
          finish       <= '1';
          state        <= IDLE;
      end case;
    end if;
  end process fsm;

  pixel_out <= not ibuf_rd_data;  -- TASK 0: invert all pixels

end architecture rtl;
