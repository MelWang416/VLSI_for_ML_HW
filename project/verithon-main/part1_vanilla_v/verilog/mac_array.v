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

  always @ (posedge clk or posedge reset) begin
   // inst_w flows to row0 to row7
	if (reset) begin
		for (j=0; j < row; j=j+1) begin
			inst_w_q[j] <= 2'b00;
		end
	end
	else begin
		inst_w_q[0] <= inst_w;
		for (j=1; j < row; j=j+1) begin
			inst_w_q[j] <= inst_w_q[j-1];
		end
	end

  end



endmodule
