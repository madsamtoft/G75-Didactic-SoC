module pixel_acc_calculator (
    input logic [7:0] s11, s12, s13, s21, s23, s31, s32, s33,
    output logic [7:0] d
);
    logic [8:0] x1, x2, x3, y1, y2, y3;
    logic [10:0] dx, dy;
    logic [9:0] dxabs, dyabs;

    always_comb begin
        x1 = s13 - s11;
        x2 = s23 - s21;
        x3 = s33 - s31;
        y1 = s11 - s31;
        y2 = s12 - s32;
        y3 = s13 - s33;

        dx = (x1 + x3) + {x2, 1'b0};
        dy = (y1 + y3) + {y2, 1'b0};

        // potential bug: -1024 will map to 1024 but this will not fit in
        // 10 bits and will truncate to 0. Ideally should round to 1023
        dxabs = dx[10] ? -dx : dx;
        dyabs = dy[10] ? -dy : dy;
        d = (dxabs + dyabs) >> 3; // Right now divides by 8, but should preferably divide by 6
    end
endmodule

module input_splitter (
    input logic [31:0] w1, w2, w3, w4, w5, w6, w7, w8, w9,
    output logic [7:0] s11[0:3],
    output logic [7:0] s12[0:3],
    output logic [7:0] s13[0:3],
    output logic [7:0] s21[0:3],
    output logic [7:0] s23[0:3],
    output logic [7:0] s31[0:3],
    output logic [7:0] s32[0:3],
    output logic [7:0] s33[0:3]
);

    assign s11[0] = w1[31:24];
    assign s12[0] = w2[7:0];
    assign s13[0] = w2[15:8];
    assign s21[0] = w4[31:24];
    assign s23[0] = w5[15:8];
    assign s31[0] = w7[31:24];
    assign s32[0] = w8[7:0];
    assign s33[0] = w8[15:8];

    assign s11[1] = w1[7:0];
    assign s12[1] = w1[15:8];
    assign s13[1] = w1[23:16];
    assign s21[1] = w5[7:0];
    assign s23[1] = w5[23:16];
    assign s31[1] = w8[7:0];
    assign s32[1] = w8[15:8];
    assign s33[1] = w8[23:16];

    assign s11[2] = w1[15:8];
    assign s12[2] = w1[23:16];
    assign s13[2] = w1[31:24];
    assign s21[2] = w5[15:8];
    assign s23[2] = w5[31:24];
    assign s31[2] = w8[15:8];
    assign s32[2] = w8[23:16];
    assign s33[2] = w8[31:24];

    assign s11[3] = w2[23:16];
    assign s12[3] = w2[31:24];
    assign s13[3] = w3[7:0];
    assign s21[3] = w5[23:16];
    assign s23[3] = w6[7:0];
    assign s31[3] = w8[23:16];
    assign s32[3] = w8[31:24];
    assign s33[3] = w9[7:0];
endmodule

module sobel_processing_core (
    input wire [31:0] row0 [0:2],
    input wire [31:0] row1 [0:2],
    input wire [31:0] row2 [0:2],
    output logic [31:0] dOut
);
    // Internal signals
    logic [7:0] s11[0:3];
    logic [7:0] s12[0:3];
    logic [7:0] s13[0:3];
    logic [7:0] s21[0:3];
    logic [7:0] s23[0:3];
    logic [7:0] s31[0:3];
    logic [7:0] s32[0:3];
    logic [7:0] s33[0:3];

    logic [7:0] d1, d2, d3, d4;

    // Instantiate modules
    input_splitter u_inputSplitter (
        .w1(row0[0]), .w2(row0[1]), .w3(row0[2]),
        .w4(row1[0]), .w5(row1[1]), .w6(row1[2]),
        .w7(row2[0]), .w8(row2[1]), .w9(row2[2]),
        .s11(s11), .s12(s12), .s13(s13), .s21(s21), .s23(s23), .s31(s31), .s32(s32), .s33(s33)
    );
    pixel_acc_calculator u_sobelProcessor1 (
        .s11(s11[0]), .s12(s12[0]), .s13(s13[0]), .s21(s21[0]), .s23(s23[0]), .s31(s31[0]), .s32(s32[0]), .s33(s33[0]),
        .d(d1)
    );
    pixel_acc_calculator u_sobelProcessor2 (
        .s11(s11[1]), .s12(s12[1]), .s13(s13[1]), .s21(s21[1]), .s23(s23[1]), .s31(s31[1]), .s32(s32[1]), .s33(s33[1]),
        .d(d2)
    );
    pixel_acc_calculator u_sobelProcessor3 (
        .s11(s11[2]), .s12(s12[2]), .s13(s13[2]), .s21(s21[2]), .s23(s23[2]), .s31(s31[2]), .s32(s32[2]), .s33(s33[2]),
        .d(d3)
    );
    pixel_acc_calculator u_sobelProcessor4 (
        .s11(s11[3]), .s12(s12[3]), .s13(s13[3]), .s21(s21[3]), .s23(s23[3]), .s31(s31[3]), .s32(s32[3]), .s33(s33[3]),
        .d(d4)
    );

    // Bind output
    // d1 is the leftmost pixel in the word, while d4 is the rightmost pixel
    assign dOut = {d4, d3, d2, d1};
endmodule
