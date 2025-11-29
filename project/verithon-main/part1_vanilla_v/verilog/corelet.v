module corelet #(
    parameter bw        = 4,
    parameter psum_bw   = 16,
    parameter col       = 8,
    parameter row       = 8
)(
    input                       clk,
    input                       reset,

    // Activation from ACT SRAM
    input  [col*psum_bw-1:0]    act_in,
    input                       act_valid,

    // Weight row from W SRAM (1 row per cycle)
    input  [row*bw-1:0]         w_in,
    input                       w_valid,     // used as L0 write enable

    // Old psum from PSUM SRAM
    input  [col*psum_bw-1:0]    old_psum,
    input                       old_psum_valid,

    // New psum to PSUM SRAM
    output [col*psum_bw-1:0]    new_psum,
    output [col-1:0]            new_psum_we,

    // Output activations to next layer
    input                       ofifo_rd,
    output [col*bw-1:0]         act_out,
    output [col-1:0]            act_out_valid,

    // inst_w = {execute, load}
    input  [1:0]                inst_w,

    // L0 controls
    input                       l0_wr,
    input                       l0_rd
);

    // 1) L0 BUFFER

    wire [row*bw-1:0] l0_out;
    wire              l0_full;
    wire              l0_ready;

    l0 #(
        .row(row),
        .bw(bw)
    ) u_l0 (
        .clk    (clk),
        .reset  (reset),
        .in     (w_in),          // weight row from W-SRAM
        .wr     (l0_wr),         // TB pulses wr during kernel load
        .rd     (l0_rd),         // TB pulses rd to rotate weights
        .out    (l0_out),        // one row per cycle out
        .o_full (l0_full),
        .o_ready(l0_ready)
    );


    // 2) MAC ARRAY

    wire [col*psum_bw-1:0] mac_psum;
    wire [col-1:0]         mac_valid;

    mac_array #(
        .bw(bw),
        .psum_bw(psum_bw),
        .col(col),
        .row(row)
    ) u_mac_array (
        .clk   (clk),
        .reset (reset),
        .in_w  (l0_out),        // NOW using L0 output
        .in_n(act_in),
        .inst_w(inst_w),        // {execute, load}
        .out_s (mac_psum),
        .valid (mac_valid)
    );


    // 3) OFIFO FOR PSUM MOVEMENT

    wire [col*psum_bw-1:0] psum_fifo_out;
    wire                   psum_fifo_valid;

    ofifo #(
        .col(col),
        .bw(psum_bw)      // FIFO stores PSUM-wide data now
    ) u_psum_fifo (
        .clk     (clk),
        .reset   (reset),
        .in      (mac_psum),
        .wr      (mac_valid),   // if any column valid
        .rd      (ofifo_rd),
        .out     (psum_fifo_out),
        .o_valid (psum_fifo_valid),
        .o_ready (),             // unused
        .o_full  ()              // unused
    );


    // 4) SFP — Accumulate + ReLU + quant

    sfp_4bit #(
        .col(col),
        .psum_bw(psum_bw),
        .act_bw(bw)
    ) u_sfp (
        .clk           (clk),
        .reset         (reset),

        .mac_psum      (psum_fifo_out),   // from OFIFO
        .mac_valid     (psum_fifo_valid),

        .old_psum      (old_psum),
        .old_psum_valid(old_psum_valid),

        .new_psum      (new_psum),        // back to PSUM SRAM
        .new_psum_we   (new_psum_we),

        .act_out       (act_out),         // to next layer
        .act_valid     (act_out_valid)
    );

endmodule
