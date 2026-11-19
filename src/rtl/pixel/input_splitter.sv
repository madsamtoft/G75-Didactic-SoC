module input_splitter (
    input logic [31:0] w1, w2, w3, w4, w5, w6, w7, w8, w9,
    input logic left, right, top, bottom,
    output logic [7:0] s11,
    output logic [7:0] s12,
    output logic [7:0] s13,
    output logic [7:0] s14,
    output logic [7:0] s15,
    output logic [7:0] s16,
    output logic [7:0] s21,
    output logic [7:0] s22,
    output logic [7:0] s23,
    output logic [7:0] s24,
    output logic [7:0] s25,
    output logic [7:0] s26,
    output logic [7:0] s31,
    output logic [7:0] s32,
    output logic [7:0] s33,
    output logic [7:0] s34,
    output logic [7:0] s35,
    output logic [7:0] s36
);

    logic p11 = w1[31:24];
    logic p12 = w2[7:0];
    logic p13 = w2[15:8];
    logic p14 = w2[23:16];
    logic p15 = w2[31:24];
    logic p16 = w3[7:0];
    logic p21 = w4[31:24];
    logic p22 = w5[7:0];
    logic p23 = w5[15:8];
    logic p24 = w5[23:16];
    logic p25 = w5[31:24];
    logic p26 = w6[7:0];
    logic p31 = w7[31:24];
    logic p32 = w8[7:0];
    logic p33 = w8[15:8];
    logic p34 = w8[23:16];
    logic p35 = w8[31:24];
    logic p36 = w9[7:0];

    assign s11 = left && top ? p22 : (left ? p12 : (top ? p12 : p11));
    assign s16 = right && top ? p25 : (right ? p15 : (top ? p26 : p16));
    assign s31 = left && bottom ? p22 : (left ? p32 : (bottom ? p21 : p31));
    assign s36 = right && bottom ? p25 : (right ? p35 : (bottom ? p26 : p36));
    assign s12 = top ? p22 : p12;
    assign s13 = top ? p23 : p13;
    assign s14 = top ? p24 : p14;
    assign s15 = top ? p25 : p15;
    assign s21 = left ? p22 : p21;
    assign s26 = right ? p25 : p26;
    assign s32 = bottom ? p22 : p32;
    assign s33 = bottom ? p23 : p33;
    assign s34 = bottom ? p24 : p34;
    assign s35 = bottom ? p25 : p35;
    assign s22 = p22;
    assign s23 = p23;
    assign s24 = p24;
    assign s25 = p25;
endmodule
