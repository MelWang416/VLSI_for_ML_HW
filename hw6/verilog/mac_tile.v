// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;

reg [bw-1:0] a_q, b_q;
reg [1:0] inst_q;
reg load_ready_q;

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b(b_q),
        .c(in_n),
	.out(out_s)
); 

always@(posedge clk) begin
  if(reset) begin
    inst_q <= 2'b0;
    load_ready_q <= 1'b0;
    a_q <= 4'b0;
    b_q <= 4'b0;
  end
  else begin
    inst_q[1] <= inst_w[1];
    if(inst_w[0] | inst_w[1]) a_q <= in_w;
    else a_q <= a_q;
    if(inst_w[0] && load_ready_q) begin
      b_q <= in_w;
      load_ready_q <= 1'b0;
    end
    else begin
      b_q <= b_q;
      load_ready_q <= load_ready_q;
    end
    if(!load_ready_q) inst_q[0] <= inst_w[0];
    else inst_q[0] <= inst_q[0];
  end

end
	  
assign out_e  = a_q;
assign inst_e = inst_q;

endmodule
