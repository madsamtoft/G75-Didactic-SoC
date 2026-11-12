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
            for (int i = 0; i < DEPTH-1; i++)
                words[i] <= words[i+1];
            words[DEPTH-1] <= word_in;
        
        end
    end

    // Corresponding columns in adjacent rows are IMG_WIDTH words apart.
    assign row0 = words[0             : 2];
    assign row1 = words[IMG_WIDTH     : IMG_WIDTH + 2];
    assign row2 = words[2 * IMG_WIDTH : 2 * IMG_WIDTH + 2];
endmodule
