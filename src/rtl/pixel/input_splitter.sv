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

    assign s11[1] = w2[7:0];
    assign s12[1] = w2[15:8];
    assign s13[1] = w2[23:16];
    assign s21[1] = w5[7:0];
    assign s23[1] = w5[23:16];
    assign s31[1] = w8[7:0];
    assign s32[1] = w8[15:8];
    assign s33[1] = w8[23:16];

    assign s11[2] = w2[15:8];
    assign s12[2] = w2[23:16];
    assign s13[2] = w2[31:24];
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
