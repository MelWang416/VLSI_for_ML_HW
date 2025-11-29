// Version B core.v
// Compatible with the provided core_tb.v interface.
// Uses:
//   - internal xmem (activation/weight memory)
//   - internal psum_mem (psum SRAM)
//   - original mac_array
//   - original sfp_4bit
//   - original ofifo

module core #(
    parameter bw      = 4,
    parameter psum_bw = 16,
    parameter col     = 8,
    parameter row     = 8
)(
    input                     clk,
    input                     reset,

    // 34 + 1 bit instruction bundle from core_tb, including a mode bit
    // inst[34] = mode_w: 0=2bit, 1=4bit
    input  [34:0]             inst,

    // Data from xmem write port (TB writes activations/weights into core)
    input  [bw*row-1:0]       D_xmem,

    // OFIFO status (TB uses this to know when it can read activations)
    output                    ofifo_valid,

    // 128-bit output psum for final checking in TB
    output [psum_bw*col-1:0]  sfp_out
);


    // 1. Decode inst[] fields (must match core_tb packing)

    wire load      = inst[0];
    wire execute   = inst[1];
    wire l0_wr     = inst[2];
    wire l0_rd     = inst[3];
    wire ififo_rd  = inst[4];
    wire ififo_wr  = inst[5];
    wire ofifo_rd  = inst[6];

    wire [10:0] A_xmem   = inst[17:7];
    wire        WEN_xmem = inst[18];   // 0: write, 1: read
    wire        CEN_xmem = inst[19];   // 0: enable

    wire [10:0] A_pmem   = inst[30:20];
    wire        WEN_pmem = inst[31];   // 0: write, 1: read
    wire        CEN_pmem = inst[32];   // 0: enable

    wire acc             = inst[33];

    wire mode_w = inst[34];


    // 2. Internal XMEM (activation/weight memory)
    //    - width: bw*row  (matches D_xmem)
    //    - depth: 2048 (like sram_32b_w2048 but parametrized)

    localparam XMEM_DEPTH = 2048;

    reg [bw*row-1:0] xmem   [0:XMEM_DEPTH-1];
    reg [bw*row-1:0] xmem_q;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            xmem_q <= {bw*row{1'b0}};
        end else begin
            // READ
            if (!CEN_xmem && WEN_xmem) begin
                xmem_q <= xmem[A_xmem];
            end

            // WRITE
            if (!CEN_xmem && !WEN_xmem) begin
                xmem[A_xmem] <= D_xmem;
            end
        end
    end


    // 3. Minimal L0: weight register & activation register
    //
    //    The real project has more complex L0 + IFIFO; here we just:
    //      - On l0_wr: capture xmem_q as weights (one row of weights).
    //      - On ififo_wr: capture xmem_q as "current activation row".
    //      - MAC sees:
    //          in_w  = weight_l0
    //          in_n  = expanded act_row_reg

    reg [bw*row-1:0] weight_l0;        // WEIGHT buffer for mac_array west input
    reg [bw*row-1:0] act_vec_q;        // ACTIVATION vector (bw*row)

    reg [bw*row-1:0] weight_l0_expanded;

    integer i;
    reg signed [1:0] w2;
    reg signed [3:0] w4;

    // Weight L0 write
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            weight_l0 <= 0;
            weight_l0_expanded <= 0;
        end
        else if (l0_wr) begin
            // xmem_q contains 32 bits
            weight_l0 <= xmem_q;

            if (mode_w == 1'b1) begin
                // === 4-bit mode: direct use ===
                weight_l0_expanded <= xmem_q;  
            end else begin
                // === 2-bit mode: unpack and sign-extend each weight ===
                for (i = 0; i < row; i = i+1) begin
                    w2 = xmem_q[2*i +: 2];        // extract 2-bit
                    w4 = { {2{w2[1]}}, w2 };      // sign-extend to 4 bits
                    weight_l0_expanded[4*i +: 4] = w4;
                end
            end
        end
    end


    // Activation capture (IFIFO-like, but simplified)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            act_vec_q <= {bw*row{1'b0}};
        end else if (ififo_wr) begin
            // TB should read activations from xmem and pulse ififo_wr
            act_vec_q <= xmem_q;
        end
    end

    // Expand act_vec_q (bw*row) into mac north input (psum_bw*col)
    // For now, map row entries into first 'row' columns and zero-fill others.
    reg [psum_bw*col-1:0] act_row_reg;
    integer ai;
    always @(*) begin
        for (ai = 0; ai < col; ai = ai+1) begin
            if (ai < row) begin
                // zero-extend bw-bit activation into psum_bw bits
                act_row_reg[psum_bw*ai +: psum_bw] =
                    {{(psum_bw-bw){1'b0}}, act_vec_q[bw*ai +: bw]};
            end else begin
                act_row_reg[psum_bw*ai +: psum_bw] = {psum_bw{1'b0}};
            end
        end
    end


    // 4. Internal PSUM memory (pmem)
    //    - width: psum_bw*col (128b)
    //    - depth: 2048
    //    - Controlled by CEN_pmem/WEN_pmem/A_pmem

    localparam PSUM_DEPTH = 2048;

    reg [psum_bw*col-1:0] psum_mem   [0:PSUM_DEPTH-1];
    reg [psum_bw*col-1:0] old_psum_reg;
    reg                   old_psum_valid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            old_psum_reg   <= {psum_bw*col{1'b0}};
            old_psum_valid <= 1'b0;
        end else begin
            old_psum_valid <= 1'b0; // default, set to 1 only on read

            // READ old_psum
            if (!CEN_pmem && WEN_pmem) begin
                old_psum_reg   <= psum_mem[A_pmem];
                old_psum_valid <= 1'b1;
            end

            // WRITE new_psum in a separate always block (below), because we need
            // new_psum & new_psum_we from SFP.
        end
    end


    // 5. MAC array instantiation
    //    - in_w:  weight_l0
    //    - in_n:  act_row_reg
    //    - inst_w: {execute, load}

    wire [psum_bw*col-1:0] mac_psum;
    wire [col-1:0]         mac_valid;

    wire [1:0] inst_w_mac = {execute, load};

    mac_array #(
        .bw(bw),
        .psum_bw(psum_bw),
        .col(col),
        .row(row)
    ) u_mac_array (
        .clk   (clk),
        .reset (reset),
        .out_s (mac_psum),
        .in_w  (weight_l0_expanded),
        .in_n  (act_row_reg),
        .inst_w(inst_w_mac),
        .valid (mac_valid)
    );


    // 6. SFP: accumulation + ReLU + 4-bit quantization

    wire [psum_bw*col-1:0] new_psum;
    wire [col-1:0]         new_psum_we;
    wire [col*bw-1:0]      act_out_sfp;
    wire [col-1:0]         act_valid_sfp;

    sfp_4bit #(
        .col(col),
        .psum_bw(psum_bw),
        .act_bw(bw)
    ) u_sfp (
        .clk           (clk),
        .reset         (reset),
        .mac_psum      (mac_psum),
        .mac_valid     (mac_valid),
        .old_psum      (old_psum_reg),
        .old_psum_valid(old_psum_valid),
        .new_psum      (new_psum),
        .new_psum_we   (new_psum_we),
        .act_out       (act_out_sfp),
        .act_valid     (act_valid_sfp)
    );

    // PSUM write-back: when TB wants write (CEN_pmem=0,WEN_pmem=0)
    // and SFP says some columns are valid.
    wire do_psum_write = (!CEN_pmem && !WEN_pmem && (|new_psum_we));

    always @(posedge clk) begin
        if (!reset && do_psum_write) begin
            psum_mem[A_pmem] <= new_psum;
        end
    end


    // 7. OFIFO: buffer activations from SFP for TB
    //    - TB will read OFIFO using ofifo_rd signal encoded in inst[6].

    wire [col*bw-1:0] ofifo_out;
    wire              ofifo_ready;
    wire              ofifo_full;

    ofifo #(
        .col(col),
        .bw(bw)
    ) u_ofifo (
        .clk     (clk),
        .reset   (reset),
        .in      (act_out_sfp), 
        .wr      (act_valid_sfp), 
        .rd      (ofifo_rd),
        .out     (ofifo_out),
        .o_valid (ofifo_valid),
        .o_ready (ofifo_ready),
        .o_full  (ofifo_full)
    );


    // 8. SFP output to TB for final accumulation checking
    //    The TB compares sfp_out against entries in out.txt.
    //    Here, we simply expose new_psum (most recent accumulated psums).

    assign sfp_out = new_psum;

endmodule
