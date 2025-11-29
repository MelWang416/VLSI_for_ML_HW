// author: Dakota Frost
module corelet(clk, reset, inst, in, out, req, ack);
    parameter inst_bw = 16;
    parameter rows = 8;
    parameter cols = 8;
    parameter psum_bw = 16;

    input clk, reset;
    input [inst_bw-1:0] inst;
    /*
    [0] request from ofifo
    [4] new cycle!!
    */
    input [4*rows-1:0] in;
    output [psum_bw*cols-1:0] out;

    input [3:0] ack; // receive controller's response
    output [3:0] req; // request from controller
    /* 
    req:
    [0]: ask for weights
    [1]: ask for activations
    [2]: inform that ofifo read ready

    ack:
    [0]: streaming weights
    [1]: streaming activations
    */

    wire [4*rows-1:0] mac_in_w;
    wire [psum_bw*rows-1:0] mac_in_n;
    wire [inst_bw*rows-1:0] mac_ii_w;
    wire [psum_bw*rows-1:0] mac_out_s;

    assign mac_in_n = 0; // TODO


    reg [7:0] state_q;
    reg [3:0] req_q;
    reg [3:0] ack_q, ack_qq, ack_qqq;
    reg [inst_bw-1:0] inst_q;
    reg [7:0] l0_rd_q = 0;
    reg [cols-1 + 2:0] ofifo_wr_q;
    assign req[1:0] = req_q[1:0];
    assign req[3] = 0;

    mac_array #(.psum_bw(psum_bw), .rows(rows), .cols(cols), .inst_bw(inst_bw)) mac_array_instance (
        .clk(clk),
        .reset(reset),
        .in_w(mac_in_w),
        .in_n(mac_in_n),
        .ii_w(mac_ii_w),
        .out_s(mac_out_s)
    );

    l0 l0_instance(
        .clk(clk),
        .reset(reset),
        .in(in),
        .out(mac_in_w),
        .rd(l0_rd_q),
        .wr(ack_q[0] || ack_q[1])
    );

    ofifo ofifo_instance(
        .clk(clk),
        .reset(reset),
        .in(mac_out_s),
        .out(out),
        .rd(req[2]),
        .wr(ofifo_wr_q[cols-1 + 1:1]),
        .rd_ready(req[2])
    );
    assign mac_ii_w = (ack_qq[0] == 1) ? ({rows{16'h0001}}) : ii_ex;

    wire [rows*inst_bw-1:0] ii_ex;
    genvar i;
    for (i=1; i<rows; i=i+1) begin
        assign ii_ex[(i+1)*inst_bw-1:i*inst_bw] = {14'h0,l0_rd_q[i-1],1'b0};
    end
    assign ii_ex[inst_bw-1:0] = {14'h0,ack_qqq[1],1'b0};



    always @(posedge clk) begin
        if (reset == 1 || inst[4]) begin
            state_q <= 0;
            req_q <= 4'b0001;
            ack_qqq <= 0;
            ack_qq <= 0;
            ack_q <= 0;
        end
        ack_qqq <= ack_qq;
        ack_qq <= ack_q;
        ack_q <= ack;
        l0_rd_q <= ack_qq[0] ? 8'b11111111 : ((l0_rd_q << 1) | ack_qqq[1]);
        ofifo_wr_q <= (ofifo_wr_q << 1) | (ack_qqq[1] & l0_rd_q[rows-1]);
        inst_q <= inst;
        if (ack_qq[0] == 1 && ack_q[0] == 0) begin
            state_q <= 1;
            req_q <= 4'b0010;
        end
        if (ack_qqq[0] == 1 && ack_qq[0] == 0) begin
            l0_rd_q <= 0;
        end
    end



endmodule