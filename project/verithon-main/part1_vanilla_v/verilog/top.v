// in_sram - l0_w - l0_a - pe - ofifo - psum_sram - sfu_acc - psum_sram
// - sfu_relu - psum_sram

module top #(
    parameter bw        = 4,
    parameter psum_bw   = 16,
    parameter col       = 8,
    parameter row       = 8
)(
    input                      clk,
    input                      reset,

    // matches core.v
    input      [33:0]          inst,

    // JEREMY AND MEL: changed D_xmem from output to input
    input  [col*bw-1:0]        D_xmem, //      [col*bw-1:0] act_out
    output                     ofifo_valid, // [col-1:0] act_out_valid
    output [col*psum_bw-1:0]   sfp_out
);

    // Decode core instruction bundle (matching core.v)
    wire load      = inst[0];
    wire execute   = inst[1];
    wire l0_wr     = inst[2];
    wire l0_rd     = inst[3];
    wire ififo_rd  = inst[4];
    wire ififo_wr  = inst[5];
    wire ofifo_rd  = inst[6];

    wire [10:0] A_xmem   = inst[17:7];
    wire        WEN_xmem = inst[18];   // 0 = write, 1 = read
    wire        CEN_xmem = inst[19];

    wire [10:0] A_pmem   = inst[30:20];
    wire        WEN_pmem = inst[31];
    wire        CEN_pmem = inst[32];

    wire acc             = inst[33];
    // wire mode_w          = inst[34]; // not used for part 1

    // Map decoded inst[] to original top inputs
    wire [10:0] act_addr   = A_xmem;
    wire        act_rd_en  = (CEN_xmem == 1'b0 && WEN_xmem == 1'b1);
    wire [31:0] act_sram_out;
    wire        act_wr_en = (CEN_xmem == 1'b0) && (WEN_xmem == 1'b0);

    wire [10:0] w_addr     = A_xmem; // <= same address space, TB will supply correct ranges
    wire        w_rd_en    = (CEN_xmem == 1'b0 && WEN_xmem == 1'b1);
    wire [31:0] w_sram_out;
    wire        w_wr_en = (CEN_xmem == 1'b0) && (WEN_xmem == 1'b0);

    wire [10:0] psum_addr  = A_pmem;
    wire        psum_rd_en = (CEN_pmem == 1'b0 && WEN_pmem == 1'b1);

    // // FIFO read directly from inst
    // wire ofifo_rd_dec = ofifo_rd;

    // ACT SRAM (31-bit)

    sram_32b_w2048 u_act_sram (
        .CLK(clk),
        .D(D_xmem),
        .Q(act_sram_out),
        .CEN(~(act_wr_en | act_rd_en)),
        .WEN(act_wr_en),
        .A(A_xmem) // act_addr
    );

    wire [col*psum_bw-1:0] act_in = act_sram_out;

    // Weight SRAM - 32 bits wide (8 elements × 4 bits)

    sram_32b_w2048 u_w_sram (
        .CLK(clk),
        .D(D_xmem),           // Direct from testbench
        .Q(w_sram_out),
        .CEN(~(w_wr_en | w_rd_en)),
        .WEN(~w_wr_en),
        .A(A_xmem)
    );

    wire [row*bw-1:0] w_in = w_sram_out;

    // PSUM SRAM - 128 bits wide (8 elements × 16 bits)
    reg bank_sel;
    wire [127:0] psum0_out, psum1_out;
    wire [127:0] current_psum_out = bank_sel ? psum1_out : psum0_out;
    
    wire psum_rd = (CEN_pmem == 1'b0) && (WEN_pmem == 1'b1);
    wire psum_wr = (CEN_pmem == 1'b0) && (WEN_pmem == 1'b0);

    always @(posedge clk or posedge reset)
        if (reset) bank_sel <= 0;
        else if (psum_wr) bank_sel <= ~bank_sel;

    sram_128b_w2048 psum0 (
        .CLK(clk), .D(sfp_out), .Q(psum0_out),
        .CEN(~((psum_rd && ~bank_sel) || (psum_wr && bank_sel))),
        .WEN(~(psum_wr && bank_sel)), .A(A_pmem)
    );

    sram_128b_w2048 psum1 (
        .CLK(clk), .D(sfp_out), .Q(psum1_out),
        .CEN(~((psum_rd && bank_sel) || (psum_wr && ~bank_sel))),
        .WEN(~(psum_wr && ~bank_sel)), .A(A_pmem)
    );

    // Corelet - needs to handle 32-bit activation input
    wire [col*psum_bw-1:0] new_psum;
    wire [col-1:0] new_psum_we;

        wire [col*psum_bw-1:0] act_in_extended;
    
    genvar i;
    generate
        for (i = 0; i < col; i = i + 1) begin : act_extend
            assign act_in_extended[(i+1)*psum_bw-1 : i*psum_bw] = 
                   {{(psum_bw-bw){1'b0}}, act_sram_out[(i+1)*bw-1 : i*bw]};
        end
    endgenerate

    corelet #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) u_corelet (
        .clk(clk), 
        .reset(reset),
        .act_in(act_in_extended),      // Use the pre-computed wire
        .act_valid(act_rd_en),
        .w_in(w_sram_out), 
        .w_valid(w_rd_en),
        .old_psum(current_psum_out), 
        .old_psum_valid(psum_rd),
        .new_psum(new_psum), 
        .new_psum_we(new_psum_we),
        .ofifo_rd(ofifo_rd),
        .inst_w({execute, load}),
        .l0_wr(l0_wr), 
        .l0_rd(l0_rd)
    );

    assign sfp_out = new_psum;
    assign ofifo_valid = |new_psum_we;

endmodule
