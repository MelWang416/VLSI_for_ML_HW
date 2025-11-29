module core(clk, reset, in, out, inst, nij, oc,
            inst_corelet, in_corelet, out_corelet, req, ack);
    parameter len_nij = 16;
    parameter len_kij = 9;
    input clk, reset;
    input [127:0] in;
    output [15:0] out;
    input [3:0] inst;
    input [10:0] nij, kij, oc;

    input [16-1:0] inst_corelet;
    input [4*8-1:0] in_corelet;
    output [16*8-1:0] out_corelet;
    input [3:0] ack; // receive controller's response
    output [3:0] req; // request from controller

    wire [140:0] mem_in;
    wire [127:0] mem_out;

    sfu sfu_instance(
        .clk(clk),
        .reset(reset),
        .in(in),
        .out(out),
        .inst(inst),
        .nij(nij),
        .oc(oc),
        .mem_in(mem_in),
        .mem_out(mem_out)
    );

    corelet corelet_instance (
        .clk(clk),
        .reset(reset),
        .inst(inst_corelet),
        .in(in_corelet),
        .out(out_corelet),
        .req(req),
        .ack(ack)
    );

    sram_128b_w2048 sram_instance (
        .CLK(clk),
        .D(mem_in[127:0]),
        .Q(mem_out),
        .CEN(mem_in[140]),
        .WEN(mem_in[139]),
        .A(mem_in[138:128])
    );


endmodule
