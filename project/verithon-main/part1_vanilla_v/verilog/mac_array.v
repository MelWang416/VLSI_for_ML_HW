// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;

  wire [psum_bw*(row+1)*col-1:0] psum_chain;
  assign psum_chain[psum_bw*col-1:0] = in_n;

  wire [row*col-1:0] valid_bus;

  assign out_s = psum_chain[psum_bw*col*(row+1)-1:psum_bw*col*row];
  assign valid = valid_bus[col*row-1:col*(row-1)];

  reg [1:0] inst_w_q [0:row-1];

  genvar i;

  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
	      .clk(clk),
	      .reset(reset),
	      .in_w(in_w[bw*i-1:bw*(i-1)]),
	      .inst_w(inst_w_q[i-1]),
	      .in_n(psum_chain[psum_bw*col*i-1:psum_bw*col*(i-1)]),
	      .out_s(psum_chain[psum_bw*col*(i+1)-1:psum_bw*col*i]),
	      .valid(valid_bus[col*i-1:col*(i-1)])
      );
  end

  integer j;

  always@(posedge clk) begin
     inst_w_q[0] <= inst_w;
     inst_w_q[1] <= inst_w_q[0];
     inst_w_q[2] <= inst_w_q[1];
     inst_w_q[3] <= inst_w_q[2];
     inst_w_q[4] <= inst_w_q[3];
     inst_w_q[5] <= inst_w_q[4];
     inst_w_q[6] <= inst_w_q[5];
     inst_w_q[7] <= inst_w_q[6];
  end 
  endmodule
