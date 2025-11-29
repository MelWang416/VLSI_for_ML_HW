// author : Dakota Frost
module mac_array(clk, reset, in_w, in_n, ii_w, out_s);
    parameter psum_bw = 16;
    parameter inst_bw = 16;
    parameter rows = 8;
    parameter cols = 8;

    input clk, reset;
    input [4*rows-1:0] in_w;
    input [psum_bw*rows-1:0] in_n;
    input [inst_bw*rows-1:0] ii_w;
    output [psum_bw*rows-1:0] out_s;

    wire [psum_bw*rows*(cols+1)-1:0] psum_tmp;
    assign psum_tmp[psum_bw*rows-1:0] = in_n;
    assign out_s = psum_tmp[psum_bw*rows*(cols+1)-1:psum_bw*rows*(cols+0)];

    genvar i;
        for (i=0; i < rows ; i=i+1) begin : mac_row
        mac_row #(.psum_bw(psum_bw), .inst_bw(inst_bw)) mac_row_instance (
            .clk(clk),
            .reset(reset),
            .in_w(in_w[4*(i+1)-1:4*i]),
            .in_n(psum_tmp[psum_bw*rows*(i+1)-1:psum_bw*rows*(i+0)]),
            .ii_w(ii_w[inst_bw*(i+1)-1:inst_bw*i]),
            .out_s(psum_tmp[psum_bw*rows*(i+2)-1:psum_bw*rows*(i+1)])
        );
        end
endmodule

module mac_row(clk, reset, in_w, in_n, ii_w, out_s);

    parameter psum_bw = 16;
    parameter inst_bw = 16;
    parameter cols = 8;

    input clk, reset;
    input [3:0] in_w;
    input [psum_bw*cols-1:0] in_n;
    input [inst_bw-1:0] ii_w;
    output [psum_bw*cols-1:0] out_s;

    wire [4*(cols+1)-1:0] x_tmp;
    assign x_tmp[3:0] = in_w;

    wire [inst_bw*(cols+1)-1:0] inst_tmp;
    assign inst_tmp[inst_bw-1:0] = ii_w;

    genvar i;
        for (i=0; i < cols; i=i+1) begin : mac_cell
        mac_cell #(.psum_bw(psum_bw), .inst_bw(inst_bw)) mac_cell_instance (
            .clk(clk),
            .reset(reset),
            .in_w(x_tmp[4*(i+1)-1:4*i]),
            .in_n(in_n[psum_bw*(i+1)-1:psum_bw*i]),
            .ii_w(inst_tmp[inst_bw*(i+1)-1:inst_bw*i]),
            .out_e(x_tmp[4*(i+2)-1:4*(i+1)]),
            .out_s(out_s[psum_bw*(i+1)-1:psum_bw*i]),
            .io_e(inst_tmp[inst_bw*(i+2)-1:inst_bw*(i+1)])
        );
        end

endmodule



module mac_cell (clk, reset, in_w, in_n, ii_w, out_e, out_s, io_e);

    parameter psum_bw = 16;
    parameter inst_bw = 16;
    /*
    [0] pass weight
    [1] pass x and psum
    [2] accept psum from north
    [3] simd_mode
    */
    input clk, reset;
    input [3:0] in_w;
    input [psum_bw-1:0] in_n;
    input [inst_bw-1:0] ii_w;
    output [3:0] out_e;
    output [psum_bw-1:0] out_s;
    output [inst_bw-1:0] io_e;

    reg signed [15:0] w0_q, w1_q;
    reg [inst_bw-1:0] inst_q;
    reg [psum_bw-1:0] psum_q;
    reg [1:0] x0_q, x1_q;

    wire [psum_bw-1:0] psum;
    wire [psum_bw-1:0] psum_debug;
    assign psum_debug = w1_q*x0_q;
    assign psum = (inst_q[1] ? in_n : psum_q) + (w0_q*x0_q + (simd_mode ? (w1_q*x1_q) : ((w1_q*x1_q) << 2)));

    wire simd_mode; // 1: use simd; 0: 4-bit mode
    assign simd_mode = inst_q[3];

    assign io_e = ii_w;
    assign out_e = inst_q[1] ? {x1_q, x0_q} : w1_q;
    assign out_s = psum_q;

    always @(posedge clk) begin
        if (reset == 1) begin
            inst_q <= 0;
            psum_q <= 0;
        end
        x0_q <= inst_q[1] ? in_w[1:0] : x0_q;
        x1_q <= inst_q[1] ? in_w[3:2] : x1_q;
        w0_q <= inst_q[0] ? (simd_mode ? w1_q : {{12{in_w[3]}},in_w}) : w0_q;
        w1_q <= inst_q[0] ? {{12{in_w[3]}},in_w} : w1_q;
        inst_q <= ii_w;
        psum_q <= psum;

    end

endmodule