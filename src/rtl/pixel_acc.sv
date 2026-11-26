// ============================================================
//  pixel_acc - STUDENT MODULE
//
//  You are given direct read access to ibuf and write access
//  to obuf. Both are synchronous BRAMs with 1-cycle read latency.
//
//  Interface:
//    start  - pulsed high for 1 cycle to begin processing
//    finish - assert high for 1 cycle when all output words
//             have been written to obuf
//
//  ibuf read port:
//    Set ibuf_rd_en=1 and ibuf_rd_addr to the word you want.
//    ibuf_rd_data is valid on the NEXT clock cycle.
//
//  obuf write port:
//    Set obuf_wr_en=1, obuf_wr_addr, obuf_wr_data on the same cycle.
//    The word is written on the rising edge.
//
//  Parameters:
//    BUF_AW    - address width (ibuf/obuf have 2^BUF_AW words)
//    BUF_DEPTH - total number of words in each buffer
//    IMG_WIDTH - frame width in words (= pixels per row / 4)
// ============================================================
module pixel_acc #(
    parameter int BUF_AW    = 15,
    parameter int BUF_DEPTH = 25344,
    parameter int IMG_WIDTH = 88      // 352 pixels / 4 pixels-per-word
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // ibuf read port
    output logic                  ibuf_rd_en,
    output logic [BUF_AW-1:0]     ibuf_rd_addr,
    input  logic [31:0]           ibuf_rd_data,

    // obuf write port
    output logic                  obuf_wr_en,
    output logic [BUF_AW-1:0]     obuf_wr_addr,
    output logic [31:0]           obuf_wr_data,

    // handshake
    input  logic                  start,
    output logic                  finish
);

    // ============================================================
    // BRAM has 1-cycle read latency, so:
    //   cycle 0: read ibuf[0] issued  (rd_data not yet valid)
    //   cycle 1: read ibuf[1] issued, ibuf[0] data valid -> write obuf[0]
    //   ...
    //   cycle N: read ibuf[N] issued (last), write obuf[N-1]
    //   cycle N+1: no new read, write obuf[N], assert finish
    //
    // ============================================================

    typedef enum logic [1:0] {
        IDLE,
        PREFETCH,
        PROCESS,
        READ_DONE
    } state_t;

    state_t state, next_state;
    logic [BUF_AW-1:0] rd_addr, next_rd_addr;
    logic [BUF_AW-1:0] wr_addr, next_wr_addr;

    localparam int HCOUNT_W = $clog2(IMG_WIDTH);
    logic [HCOUNT_W-1:0] hcount, next_hcount;
    logic left, right, top, bottom;

    logic [31:0] row0 [0:2];
    logic [31:0] row1 [0:2];
    logic [31:0] row2 [0:2];

    pixel_shift_reg #(
        .WORD_WIDTH(32),
        .IMG_WIDTH(IMG_WIDTH)
    ) i_shift_reg (
        .clk     (clk),
        .rst_n   (rst_n),
        .word_in (ibuf_rd_data),
        .row0    (row0),
        .row1    (row1),
        .row2    (row2)
    );

    sobel_processing_core u_processor (
        .row0   (row0),
        .row1   (row1),
        .row2   (row2),
        .left   (left),
        .right  (right),
        .top    (top),
        .bottom (bottom),
        .dOut   (obuf_wr_data)
    );

    always_comb begin
        next_state = state;
        
        next_rd_addr <= '0;
        next_wr_addr <= '0;
        next_hcount <= '0;

        left <= hcount == 0;
        right <= hcount == IMG_WIDTH - 1;
        top <= wr_addr < IMG_WIDTH;
        bottom <= wr_addr >= BUF_DEPTH - IMG_WIDTH;

        ibuf_rd_en <= 1'b0;
        ibuf_rd_addr <= rd_addr;
        obuf_wr_en <= 1'b0;
        obuf_wr_addr <= wr_addr;
        finish <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_rd_addr <= 1;
                    ibuf_rd_en <= 1'b1;
                    next_state <= PREFETCH;
                end
            end

            PREFETCH: begin
                next_rd_addr <= rd_addr + 1;
                ibuf_rd_en <= 1'b1;
                if (rd_addr == IMG_WIDTH + 2) begin
                    next_state <= PROCESS;
                end
            end

            PROCESS: begin
                next_rd_addr <= rd_addr + 1;
                ibuf_rd_en <= rd_addr < BUF_DEPTH;
                next_wr_addr <= wr_addr + 1;
                obuf_wr_en <= 1'b1;
                if (hcount == IMG_WIDTH - 1) begin
                    next_hcount <= '0;
                end
                else begin
                    next_hcount <= hcount + 1;
                end
                if (wr_addr == BUF_DEPTH - 1) begin
                    next_state <= IDLE;
                    finish <= 1'b1;
                end
            end

            default: next_state <= IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            rd_addr <= '0;
            wr_addr <= '0;
            hcount <= '0;
        end
        else begin
            state <= next_state;
            rd_addr <= next_rd_addr;
            wr_addr <= next_wr_addr;
            hcount <= next_hcount;
        end
    end
endmodule
