// author: Dakota Frost
module ofifo (clk, reset, in, out, rd, wr, rd_ready);
  parameter cols = 8;
  parameter psum_bw = 16;


  input  clk, reset;
  input  [cols-1:0] wr;
  input  rd;
  input  [cols*psum_bw-1:0] in;
  output [cols*psum_bw-1:0] out;
  output rd_ready;

  wire [cols-1:0] empty;
  wire [cols-1:0] full;
  reg [cols-1:0] rd_en;

  assign rd_ready = (empty == 0);
  
  genvar i;

  for (i=0; i<cols ; i=i+1) begin : fifo64
      fifo_depth64 #(.bw(psum_bw)) fifo_instance ( // TODO: use a shallower fifo
         .rd_clk(clk),
         .wr_clk(clk),
         .rd(rd),
         .wr(wr[i]),
         .o_empty(empty[i]),
         .o_full(full[i]),
         .in(in[(i+1)*psum_bw-1:i*psum_bw]),
         .out(out[(i+1)*psum_bw-1:i*psum_bw]),
         .reset(reset)
      );
   end
endmodule