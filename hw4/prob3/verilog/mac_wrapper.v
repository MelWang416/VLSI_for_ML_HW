// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_wrapper (clk, out, a0, a1, a2, a3, b0, b1, b2, b3, c);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out;
input  [bw-1:0] a0, a1, a2, a3;
input  [bw-1:0] b0, b1, b2, b3;
input  [psum_bw-1:0] c;
input  clk;

reg    [bw-1:0] a0_q, a1_q, a2_q, a3_q;
reg    [bw-1:0] b0_q, b1_q, b2_q, b3_q;
reg    [psum_bw-1:0] c_q;

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a0(a0_q), 
        .b0(b0_q),
        .a1(a1_q), 
        .b1(b1_q),
        .a2(a2_q), 
        .b2(b2_q),
        .a3(a3_q), 
        .b3(b3_q),
        .c(c_q),
	.out(out)
); 

always @ (posedge clk) begin
        b0_q  <= b0;
        a0_q  <= a0;
        b1_q  <= b1;
        a1_q  <= a1;
        b2_q  <= b2;
        a2_q  <= a2;
        b3_q  <= b3;
        a3_q  <= a3;	
        c_q  <= c;
end

endmodule
