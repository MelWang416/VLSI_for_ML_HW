// author: Dakota Frost
module l0 (clk, reset, in, out, rd, wr);

  parameter rows  = 8;


  input  clk, reset;
  input  wr;
  input  [rows-1:0] rd;
  input  [rows*4-1:0] in;
  output [rows*4-1:0] out;

  wire [rows-1:0] empty;
  wire [rows-1:0] full;
  reg [rows-1:0] rd_en;

  
  genvar i;

  for (i=0; i<rows ; i=i+1) begin : fifo64
      fifo_depth64 #(.bw(4)) fifo_instance ( /// TODO, we do not need this deep of a fifo.
         .rd_clk(clk),
         .wr_clk(clk),
         .rd(rd[i]),
         .wr(wr), // TODO?
         .o_empty(empty[i]),
         .o_full(full[i]),
         .in(in[(i+1)*4-1:i*4]),
         .out(out[(i+1)*4-1:i*4]),
         .reset(reset)
      );
   end

endmodule
