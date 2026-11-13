module shift_reg #(
    parameter int WORD_WIDTH = 32,
    parameter int IMG_WIDTH  = 88  // Words per image row
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  clear,
    input  logic                  push,
    input  logic [WORD_WIDTH-1:0] word_in,
    output wire  [WORD_WIDTH-1:0] row0 [0:2],
    output wire  [WORD_WIDTH-1:0] row1 [0:2],
    output wire  [WORD_WIDTH-1:0] row2 [0:2]
);
    localparam int DEPTH = 2 * IMG_WIDTH + 3;

    localparam int IDX_W1 = 2 * IMG_WIDTH + 2;
    localparam int IDX_W2 = 2 * IMG_WIDTH + 1;
    localparam int IDX_W3 = 2 * IMG_WIDTH + 0;
    localparam int IDX_W4 = IMG_WIDTH + 2;
    localparam int IDX_W5 = IMG_WIDTH + 1;
    localparam int IDX_W6 = IMG_WIDTH + 0;
    localparam int IDX_W7 = 2;
    localparam int IDX_W8 = 1;
    localparam int IDX_W9 = 0;

    logic [WORD_WIDTH-1:0] words [0:DEPTH-1];

    // Slot 0 is the oldest word. A push appends at the last slot.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++)
                words[i] <= '0;
        end else if (clear) begin
            for (int i = 0; i < DEPTH; i++)
                words[i] <= '0;
        end else if (push) begin
            words <= {words[1:DEPTH-1], word_in};
        end
    end

    // Debugging signals
    wire [WORD_WIDTH-1:0]w1 = words[IDX_W1];
    wire [WORD_WIDTH-1:0]w2 = words[IDX_W2];
    wire [WORD_WIDTH-1:0]w3 = words[IDX_W3];
    wire [WORD_WIDTH-1:0]w4 = words[IDX_W4];
    wire [WORD_WIDTH-1:0]w5 = words[IDX_W5];
    wire [WORD_WIDTH-1:0]w6 = words[IDX_W6];
    wire [WORD_WIDTH-1:0]w7 = words[IDX_W7];
    wire [WORD_WIDTH-1:0]w8 = words[IDX_W8];
    wire [WORD_WIDTH-1:0]w9 = words[IDX_W9];

    // Corresponding columns in adjacent rows are IMG_WIDTH words apart.
    assign row0 = words[0             : 2];
    assign row1 = words[IMG_WIDTH     : IMG_WIDTH + 2];
    assign row2 = words[2 * IMG_WIDTH : 2 * IMG_WIDTH + 2];
endmodule
