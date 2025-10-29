// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac (out, a, b, c);

parameter bw = 4;
parameter psum_bw = 16;

input unsigned [bw-1:0] a;
input signed [bw-1:0] b;
input signed [psum_bw-1:0] c;
output reg [psum_bw-1:0] out;
wire signed [bw:0] a_sign;
wire signed [bw:0] b_sign;

assign a_sign = {1'b0, {a}};
assign b_sign = {{b[bw-1]}, {b}};

always@(*) begin
	out = a_sign*b_sign + c;
end


endmodule
