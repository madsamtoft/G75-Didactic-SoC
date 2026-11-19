module sobel_processing_core (
    input wire [31:0] row0 [0:2],
    input wire [31:0] row1 [0:2],
    input wire [31:0] row2 [0:2],
    input logic left, right, top, bottom,
    output logic [31:0] dOut
);
    // Internal signals
    logic [7:0] s11;
    logic [7:0] s12;
    logic [7:0] s13;
    logic [7:0] s14;
    logic [7:0] s15;
    logic [7:0] s16;
    logic [7:0] s21;
    logic [7:0] s22;
    logic [7:0] s23;
    logic [7:0] s24;
    logic [7:0] s25;
    logic [7:0] s26;
    logic [7:0] s31;
    logic [7:0] s32;
    logic [7:0] s33;
    logic [7:0] s34;
    logic [7:0] s35;
    logic [7:0] s36;

    logic [7:0] d1, d2, d3, d4;

    // Instantiate modules
    input_splitter u_inputSplitter (
        .w1(row0[0]), .w2(row0[1]), .w3(row0[2]),
        .w4(row1[0]), .w5(row1[1]), .w6(row1[2]),
        .w7(row2[0]), .w8(row2[1]), .w9(row2[2]),
        .left(left), .right(right), .top(top), .bottom(bottom),
        .s11(s11), .s12(s12), .s13(s13), .s14(s14), .s15(s15), .s16(s16),
        .s21(s21), .s22(s22), .s23(s23), .s24(s24), .s25(s25), .s26(s26),
        .s31(s31), .s32(s32), .s33(s33), .s34(s34), .s35(s35), .s36(s36)
    );
    pixel_acc_calculator u_sobelProcessor1 (
        .s11(s11), .s12(s12), .s13(s13), .s21(s21), .s23(s23), .s31(s31), .s32(s32), .s33(s33),
        .d(d1)
    );
    pixel_acc_calculator u_sobelProcessor2 (
        .s11(s12), .s12(s13), .s13(s14), .s21(s22), .s23(s24), .s31(s32), .s32(s33), .s33(s34),
        .d(d2)
    );
    pixel_acc_calculator u_sobelProcessor3 (
        .s11(s13), .s12(s14), .s13(s15), .s21(s23), .s23(s25), .s31(s33), .s32(s34), .s33(s35),
        .d(d3)
    );
    pixel_acc_calculator u_sobelProcessor4 (
        .s11(s14), .s12(s15), .s13(s16), .s21(s24), .s23(s26), .s31(s34), .s32(s35), .s33(s36),
        .d(d4)
    );

    // Bind output
    // d1 is the leftmost pixel in the word, while d4 is the rightmost pixel
    assign dOut = {
        d4,
        d3,
        d2,
        d1
    };
endmodule