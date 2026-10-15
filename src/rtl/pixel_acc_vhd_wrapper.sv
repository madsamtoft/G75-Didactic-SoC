/*
  Contributors:
    * Dovydas Liutkus (dovli@dtu.dk)
  Description:
    * SystemVerilog wrapper for the VHDL accelerator (pixel_acc_vhd.vhd)
    *
    * To use the VHDL accelerator, add ACC_LANG=vhdl to make commands run
    * from the project root, e.g.:
    *   make test_ss ACC_LANG=vhdl
    *   make test_all TEST=pixel_inversion ACC_LANG=vhdl
    * sim/Makefile and fpga/scripts/run_xilinx.tcl then compile this
    * wrapper and pixel_acc_vhd.vhd instead of pixel_acc.sv.
    *
    * NOTE: compile only one of pixel_acc.sv / pixel_acc_vhd_wrapper.sv,
    * both define module pixel_acc.
*/

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

    pixel_acc_vhd #(
        .BUF_AW    (BUF_AW),
        .BUF_DEPTH (BUF_DEPTH),
        .IMG_WIDTH (IMG_WIDTH)
    ) i_vhd (
        .clk          (clk),
        .rst_n        (rst_n),
        .ibuf_rd_en   (ibuf_rd_en),
        .ibuf_rd_addr (ibuf_rd_addr),
        .ibuf_rd_data (ibuf_rd_data),
        .obuf_wr_en   (obuf_wr_en),
        .obuf_wr_addr (obuf_wr_addr),
        .obuf_wr_data (obuf_wr_data),
        .start        (start),
        .finish       (finish)
    );

endmodule
