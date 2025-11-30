// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module l0 (clk, in, out, rd, wr, o_full, reset, o_ready);

  parameter row  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [row*bw-1:0] in;
  output [row*bw-1:0] out;
  output o_full;
  output o_ready;

  wire [row-1:0] empty;
  wire [row-1:0] full;
  reg [row-1:0] rd_en;

  //reg [2:0] rr_ptr; // pointer
  
  genvar i;

  assign o_ready = !full[0] && !full[1] && !full[2] && !full[3] && !full[4] && !full[5] && !full[6] && !full[7];
  assign o_full  = |full;


  for (i=0; i<row ; i=i+1) begin : row_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
	 .rd(rd_en[i]),
	 .wr(wr),
         .o_empty(empty[i]),
         .o_full(full[i]),
	 .in(in[(i+1)*bw-1 : i*bw]),
	 .out(out[(i+1)*bw-1 : i*bw]),
         .reset(reset));
  end


  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 8'b00000000;
      //rr_ptr <= 3'b000;
   end
   else

      /////////////// version1: read all row at a time ////////////////
      ///////////////////////////////////////////////////////

//      rd_en <= (rd ? 8'b11111111 : 8'b00000000);

      //////////////// version2: read 1 row at a time /////////////////
      ///////////////////////////////////////////////////////
      
      if (rd==1'b1) begin
	      rd_en <= {rd_en[6:0], 1'b1};
	      //rd_en[rr_ptr] <= 1'b1;
	      //rr_ptr <= rr_ptr + 1;
      end else begin
	      rd_en <= {rd_en[6:0], 1'b0};
      end

    end

endmodule
