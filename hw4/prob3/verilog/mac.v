// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac (out, a0, a1, a2, a3, b0, b1, b2, b3, c);

parameter bw = 4;
parameter psum_bw = 16;

input unsigned [bw-1:0] a0, a1, a2, a3;
input signed [bw-1:0] b0, b1, b2, b3;
input signed [psum_bw-1:0] c;
output reg [psum_bw-1:0] out;
wire signed [bw:0] a0_sign, a1_sign, a2_sign, a3_sign;
wire signed [bw:0] b0_sign, b1_sign, b2_sign, b3_sign;
reg signed [7:0] pd_0_mac, pd_1_mac, pd_2_mac, pd_3_mac;
reg signed [8:0] sum_0_mac, sum_1_mac;

assign a0_sign = {1'b0, {a0}};
assign a1_sign = {1'b0, {a1}};
assign a2_sign = {1'b0, {a2}};
assign a3_sign = {1'b0, {a3}};

assign b0_sign = {{b0[bw-1]}, {b0}};
assign b1_sign = {{b1[bw-1]}, {b1}};
assign b2_sign = {{b2[bw-1]}, {b2}};
assign b3_sign = {{b3[bw-1]}, {b3}};

always@(*) begin
	pd_0_mac = a0_sign*b0_sign;
	pd_1_mac = a1_sign*b1_sign;
	pd_2_mac = a2_sign*b2_sign;
	pd_3_mac = a3_sign*b3_sign;
	sum_0_mac = pd_0_mac + pd_1_mac;
	sum_1_mac = pd_2_mac + pd_3_mac;
        out = sum_0_mac + sum_1_mac + c;	
end


endmodule
