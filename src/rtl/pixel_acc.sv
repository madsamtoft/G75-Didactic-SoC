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

    typedef enum logic [2:0] {
        IDLE, LOAD, RUN, ROTATE, DONE
    } state_t;

    state_t state;

    logic [BUF_AW-1:0] rd_addr;   // current ibuf read address
    logic [BUF_AW-1:0] wr_addr;   // current obuf write address (= rd_addr delayed 1 cycle)
    logic              pipe_valid; // 0 on first PROCESS cycle (rd_data not yet valid)
    logic [31:0] pixel_out;

    localparam int IMAGE_PIXEL_WIDTH = IMG_WIDTH * 4;
    localparam int HEIGHT = BUF_DEPTH / IMG_WIDTH;
    localparam int OUT_WIDTH = IMAGE_PIXEL_WIDTH - 2;
    localparam int OUT_HEIGHT = HEIGHT - 2;

    // Four complete row buffers
    logic [31:0] row0 [0:IMG_WIDTH-1];
    logic [31:0] row1 [0:IMG_WIDTH-1];
    logic [31:0] row2 [0:IMG_WIDTH-1];
    logic [31:0] row3 [0:IMG_WIDTH-1];

    // Physical buffer roles
    logic [1:0] top_sel, mid_sel, bot_sel, next_sel;

    // Continuous BRAM read pipeline
    logic req_valid, resp_valid;
    logic [BUF_AW-1:0] req_index, resp_index;

    int unsigned issue_count;
    int unsigned receive_count;

    logic load_done;
    logic compute_done;

    // Sobel control
    int unsigned output_y;
    int unsigned window_x;
    logic [3:0] kernel_idx;
    logic emit_pixel;

    logic signed [12:0] gx_acc, gy_acc;
    logic signed [2:0] kx, ky;
    logic [7:0] current_pixel;

    // Pixel selection
    int unsigned sample_x, word_idx, byte_idx;
    logic [1:0] bank_sel;
    logic [31:0] selected_word;

    // Output processing
    logic [12:0] abs_gx, abs_gy;
    logic [13:0] magnitude;
    logic [7:0] edge_pixel;
    logic [31:0] packed_word, next_word;


    // SOBEL PIXEL AND COEFFICIENT SELECTION
    always_comb begin

        // Top-left position of 3x3 window
        sample_x = window_x + kernel_idx % 3; // x offset:    0 1 2 | 0 1 2 | 0 1 2

        word_idx = sample_x / 4;
        byte_idx = sample_x % 4;

        case (kernel_idx / 3) //sample_y sel bank for the kernel, something like 0 0 0 | 1 1 1 | 2 2 2
            0: bank_sel = top_sel;
            1: bank_sel = mid_sel;
            default: bank_sel = bot_sel; //
        endcase

        selected_word = 0;

        case (bank_sel)
            0: selected_word = row0[word_idx];
            1: selected_word = row1[word_idx];
            2: selected_word = row2[word_idx];
            3: selected_word = row3[word_idx];
        endcase

        current_pixel = selected_word[8*byte_idx +: 8];
        kx = 0;
        ky = 0;

        case (kernel_idx)
            0: begin kx=-1; ky=-1; end
            1: begin kx= 0; ky=-2; end
            2: begin kx= 1; ky=-1; end
            3: begin kx=-2; ky= 0; end
            4: begin kx= 0; ky= 0; end // Could not include, but meh
            5: begin kx= 2; ky= 0; end
            6: begin kx=-1; ky= 1; end
            7: begin kx= 0; ky= 2; end
            8: begin kx= 1; ky= 1; end
            default: begin kx=0; ky=0; end
        endcase
    end

    // MAGNITUDE CALCULATION AND PUT IT IN A NEW WORD
    always_comb begin
        abs_gx = (gx_acc < 0) ? -gx_acc : gx_acc;
        abs_gy = (gy_acc < 0) ? -gy_acc : gy_acc;
        magnitude = {1'b0, abs_gx} + {1'b0, abs_gy};
        edge_pixel = magnitude > 255 ? 8'd255 : magnitude[7:0];
        next_word = packed_word;
        next_word[8*(window_x % 4) +: 8] = edge_pixel;
        if (window_x == OUT_WIDTH-1) // Border case handled to zero/ Black coloumns
            next_word[31:16] = 16'b0;
    end

    // ---- FSM ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state      <= IDLE;
            rd_addr    <= '0;
            wr_addr    <= '0;
            pipe_valid <= 1'b0;
            ibuf_rd_en <= 1'b0;
            obuf_wr_en <= 1'b0;
            finish     <= 1'b0;

            top_sel <= 0;
            mid_sel <= 1;
            bot_sel <= 2;
            next_sel <= 3;

            req_valid <= 0;
            resp_valid <= 0;
            req_index <= 0;
            resp_index <= 0;
            issue_count <= 0;
            receive_count <= 0;

            output_y <= 0;
            window_x <= 0;
            kernel_idx <= 0;
            emit_pixel <= 0;

            gx_acc <= 0;
            gy_acc <= 0;
            packed_word <= 0;

            compute_done <= 0;
            load_done <= 0;
        end else begin
            ibuf_rd_en <= 1'b0;
            obuf_wr_en <= 1'b0;
            finish     <= 1'b0;

            // to match the BRAM read response, delay 1 clock
            req_valid <= 0;
            resp_valid <= req_valid;
            resp_index <= req_index;

            case (state)
                IDLE: begin
                    if (start) begin
                        top_sel <= 0;
                        mid_sel <= 1;
                        bot_sel <= 2;
                        next_sel <= 3;

                        req_valid <= 0;
                        resp_valid <= 0;
                        issue_count <= 0;
                        receive_count <= 0;

                        output_y <= 0;
                        window_x <= 0;
                        kernel_idx <= 0;
                        emit_pixel <= 0;

                        gx_acc <= 0;
                        gy_acc <= 0;
                        packed_word <= 0;

                        compute_done <= 0;
                        load_done <= 0;

                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Issue one read every clock
                    if (issue_count < 3*IMG_WIDTH) begin
                        ibuf_rd_en <= 1;
                        ibuf_rd_addr <= BUF_AW'(issue_count);

                        req_valid <= 1;
                        req_index <= BUF_AW'(issue_count);

                        issue_count <= issue_count + 1;
                    end

                    // Capture returned words
                    if (resp_valid) begin
                        if (resp_index < IMG_WIDTH)
                            row0[resp_index] <= ibuf_rd_data;
                        else if (resp_index < 2*IMG_WIDTH)
                            row1[resp_index-IMG_WIDTH] <= ibuf_rd_data;
                        else
                            row2[resp_index-2*IMG_WIDTH] <= ibuf_rd_data;
                        //receive_count is a counter for when the buffer have loaded a value
                        receive_count <= receive_count + 1;

                        // All three rows received
                        if (receive_count == 3*IMG_WIDTH-1) begin
                            issue_count <= 0;
                            receive_count <= 0;

                            load_done <= (HEIGHT <= 3);
                            state <= RUN;
                        end
                    end
                end

                RUN: begin //Compute and load when we rotate
                    if (!compute_done) begin
                        if (!emit_pixel) begin
                            gx_acc <= gx_acc + $signed({1'b0,current_pixel})*kx;
                            gy_acc <= gy_acc + $signed({1'b0,current_pixel})*ky;

                            if (kernel_idx == 8) begin
                                kernel_idx <= 0;
                                emit_pixel <= 1;
                            end else begin
                                kernel_idx <= kernel_idx + 1;
                            end

                        end else begin

                            // Emit completed Sobel pixel
                            packed_word <= next_word;

                            // Every four pixels form a word.
                            // Final word can be partially full.
                            if ((window_x % 4 == 3) || (window_x == OUT_WIDTH-1)) begin
                                obuf_wr_en <= 1;
                                obuf_wr_addr <= BUF_AW'(output_y * IMG_WIDTH + window_x/4);
                                obuf_wr_data <= next_word;
                            end

                            if (window_x == OUT_WIDTH-1)
                                compute_done <= 1;
                            else
                                window_x <= window_x + 1;

                            gx_acc <= 0;
                            gy_acc <= 0;
                            emit_pixel <= 0;
                        end
                    end

                    if (!load_done) begin //Stream next row when rotate
                        if (issue_count < IMG_WIDTH) begin

                            ibuf_rd_en <= 1;
                            ibuf_rd_addr <= BUF_AW'((output_y+3)*IMG_WIDTH + issue_count);

                            req_valid <= 1;
                            req_index <= BUF_AW'(issue_count);

                            issue_count <= issue_count + 1;
                        end

                        // Put word into the row that is selected to be replaced
                        if (resp_valid) begin
                            case (next_sel)
                                0: row0[resp_index] <= ibuf_rd_data;
                                1: row1[resp_index] <= ibuf_rd_data;
                                2: row2[resp_index] <= ibuf_rd_data;
                                3: row3[resp_index] <= ibuf_rd_data;
                            endcase
                            receive_count <= receive_count + 1;

                            if (receive_count == IMG_WIDTH-1)
                                load_done <= 1;
                        end
                    end

                    //Rotate when we have loaded and finished compute a row
                    if (compute_done && load_done) begin

                        if (output_y == OUT_HEIGHT-1)
                            state <= DONE;
                        else
                            state <= ROTATE;

                    end
                end

                ROTATE: begin //Resets value to recalculate

                    top_sel <= mid_sel;
                    mid_sel <= bot_sel;
                    bot_sel <= next_sel;
                    next_sel <= top_sel;

                    output_y <= output_y + 1;

                    window_x <= 0;
                    kernel_idx <= 0;
                    emit_pixel <= 0;
                    compute_done <= 0;

                    gx_acc <= 0;
                    gy_acc <= 0;
                    packed_word <= 0;

                    issue_count <= 0;
                    receive_count <= 0;

                    // Check if we have reached the end.
                    load_done <= (output_y+4 >= HEIGHT);

                    state <= RUN;
                end

                DONE: begin
                    finish <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule