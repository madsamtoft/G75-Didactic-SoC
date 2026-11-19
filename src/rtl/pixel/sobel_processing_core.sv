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

    // Debugging signals
    wire [7:0] p11 = s11[0];
    wire [7:0] p12 = s12[0];
    wire [7:0] p13 = s12[1];
    wire [7:0] p14 = s12[2];
    wire [7:0] p15 = s12[3];
    wire [7:0] p16 = s13[3];
    wire [7:0] p21 = s21[0];
    wire [7:0] p26 = s23[3];
    wire [7:0] p31 = s31[0];
    wire [7:0] p32 = s32[0];
    wire [7:0] p33 = s32[1];
    wire [7:0] p34 = s32[2];
    wire [7:0] p35 = s32[3];
    wire [7:0] p36 = s33[3];

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
    assign dOut = {
        d4 > 0 ? 8'hFF : 8'h00,
        d3 > 0 ? 8'hFF : 8'h00,
        d2 > 0 ? 8'hFF : 8'h00,
        d1 > 0 ? 8'hFF : 8'h00
    };
endmodule