// author : Dakota Frost
module sfu(clk, reset, in, out, inst, nij, oc, mem_in, mem_out);
    parameter len_nij = 16;
    parameter len_kij = 9;
    input clk, reset;
    input [127:0] in;
    output [15:0] out;
    input [3:0] inst;
    input [10:0] nij, kij, oc;
    output [140:0] mem_in;
    input [127:0] mem_out;
    /*
    [0] - write
    [1] - run acc for all
    [2] - get output
    */

    reg [10:0] mem_A = len_nij;
    reg timer = 0; // for accumulating psums
    reg timer_q = 0;
    reg [10:0] oc_q, oc_qq;
    wire cen, wen;
    assign cen = inst[0] || timer || inst[2];
    assign wen = inst[0] || (timer && mem_A < len_nij);
    wire [127:0] tmp_out;


    reg [127:0] acc_q = 0;
    wire [127:0] acc;

    assign out = tmp_out[16*oc_qq +: 16];

    assign mem_in = {~cen, ~wen, inst[2] ? nij : mem_A, 
        timer ? acc : in};
    assign tmp_out = mem_out;

    genvar i;
    for (i=0; i<128; i=i+16) begin
        assign acc[i+15:i] = (timer_q == 1 && mem_A < len_kij*len_nij) ? acc_q[i+15:i] + tmp_out[i+15:i] : 0;
    end

    always @(posedge clk) begin
        timer_q <= timer;
        oc_q <= oc;
        oc_qq <= oc_q;
        if (timer == 1) begin
            acc_q <= acc;
            if (mem_A == 0) timer <= 0;
            if (mem_A < len_nij) acc_q <= 0;
            mem_A <= (mem_A < len_nij) ? mem_A + len_kij*len_nij-1 : mem_A - len_nij;
        end
        else begin
            if (inst[1] == 1) begin
                timer <= 1;
                acc_q <= 0;
                mem_A <= (len_kij+1)*len_nij-1;
            end
            if (inst[0] == 1) begin
                mem_A <= mem_A + 1;
            end
        end
    end
endmodule