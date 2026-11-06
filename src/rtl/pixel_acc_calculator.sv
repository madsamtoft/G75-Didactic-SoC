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
        d = (dxabs + dyabs) >> 3;
    end
endmodule
