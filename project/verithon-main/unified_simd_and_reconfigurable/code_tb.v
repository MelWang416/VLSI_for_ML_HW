// author: Dakota Frost
`timescale 1ns/1ps

module core_tb;

  parameter len_nij = 36;
  parameter len_nij_unpadded = 16;
  parameter len_ni = 6;
  parameter len_ni_unpadded = 4;
  parameter len_ki = 3;
  parameter len_kij = 9;
  parameter channels = 8;

  reg clk = 0;
  reg reset = 1;

  wire [3:0] req;
  reg[3:0] ack = 0;
  reg [15:0] inst = 0;
  wire [16*8-1:0] corelet_out;

  reg[10:0] mem_A = 0;
  reg mem_CEN, mem_WEN;
  reg [31:0] mem_D;
  wire [31:0] mem_Q;
  reg [3:0] read_tmp;
  reg [15:0] psum_test;
  reg [15:0] psum_test_q = 0;

  wire [3:0] sfu_inst;
  reg [2:0] sfu_q = 0;
  assign sfu_inst[0] = req[2];
  assign sfu_inst[3:1] = sfu_q;
  wire [15:0] sfu_out;
  reg [10:0] sfu_nij, sfu_oc;

  integer x_file, x_scan_file, w_file, w_scan_file, acc_file, acc_scan_file;
  integer captured_data;
  integer i, t, ic, oc, kx, ky, nx, ny, err;




  sram_32b_w2048 sram_instance (
    .CLK(clk),
    .D(mem_D),
    .Q(mem_Q),
    .CEN(mem_CEN),
    .WEN(mem_WEN),
    .A(mem_A)
  );

  core core_instance (
    .clk(clk),
    .reset(reset),
    .in(corelet_out),
    .out(sfu_out),
    .inst(sfu_inst),
    .nij(sfu_nij),
    .oc(sfu_oc),
    .inst_corelet(inst),
    .in_corelet(mem_Q),
    .out_corelet(corelet_out),
    .req(req),
    .ack(ack)
  );


  initial begin

    mem_A = 0;
    mem_CEN = 1;
    mem_WEN = 0;

    $dumpfile("core_tb.vcd");
    $dumpvars(0,core_tb);

    x_file = $fopen("tb/x.txt", "r");
    w_file = $fopen("tb/w.txt", "r");

    //////// Reset /////////
    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1;

    for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    /////////////////////////

    /////// Activation data writing to memory ///////
    for (t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; mem_D = 0;
      for (ic=0; ic<channels; ic=ic+1) begin
        x_scan_file = $fscanf(x_file,"%32b", read_tmp); mem_D = mem_D | (read_tmp << (4*ic));
      end
      mem_WEN = 0; mem_CEN = 0; mem_A = 11'b00000000000 + t;
      #0.5 clk = 1'b1;
    end
    #0.5 clk = 1'b0;  mem_WEN = 1;  mem_CEN = 1; mem_A = 0;
    #0.5 clk = 1'b1;

    $fclose(x_file);
    /////////////////////////////////////////////////
    /////// Weight data writing to memory ///////
    for (t=0; t<len_kij; t=t+1) begin
      for (oc=0; oc<channels; oc=oc+1) begin
        #0.5 clk = 1'b0; mem_D = 0;
        for (ic=0; ic<channels; ic=ic+1) begin
          w_scan_file = $fscanf(w_file,"%32b", read_tmp); mem_D = mem_D | (read_tmp << (4*ic));
        end
        mem_WEN = 0; mem_CEN = 0; mem_A = 11'b10000000000 + t*channels + oc;
        #0.5 clk = 1'b1;
      end
    end
    #0.5 clk = 1'b0;  mem_WEN = 1;  mem_CEN = 1; mem_A = 0;
    #0.5 clk = 1'b1;

    $fclose(w_file);
    /////////////////////////////////////////////////

    /************ LOAD WEIGHTS TO L0 *************/
    for (ky=0; ky<len_ki; ky=ky+1) begin
      for (kx=0; kx<len_ki; kx=kx+1) begin
        t = ky*len_ki + kx;
        inst[4] = 1;
        while (req[0] != 1) begin
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;
        end
        inst[4] = 0;
        ack[0] = 1;
        for (oc=channels-1; oc>=0; oc=oc-1) begin
          mem_WEN = 1; mem_CEN = 0; mem_A = 11'b10000000000 + t*channels + oc;
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;
        end
        mem_CEN = 1;
        ack[0] = 0;
        /******************[END SECTION]*****************/
        /************ LOAD ACTIVATIONS TO L0 *************/
        while (req[1] != 1) begin
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;
        end
        ack[1] = 1;
        for (ny=0; ny<len_ni_unpadded; ny=ny+1) begin
          for (nx=0; nx<len_ni_unpadded; nx=nx+1) begin
            mem_WEN = 1; mem_CEN = 0; mem_A = 11'b00000000000 + (ny+ky)*len_ni + (nx+kx);
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
          end
        end
        for (i=0; i<channels ; i=i+1) begin // TODO remove with inst fix
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;
        end
        ack[1] = 0;
        /******************[END SECTION]*****************/

        for (i=0; i<20 ; i=i+1) begin // TODO: handshake?
          #0.5 clk = 1'b0;
          #0.5 clk = 1'b1;
        end
        $display("processed weight ki,kj = %1d,%1d", kx, ky);
      end
    end

    sfu_q[0] = 1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    sfu_q[0] = 0;
    for (i=0; i<200 ; i=i+1) begin // todo: add req/ack
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    /////// Verify Psums ///////
    err = 0;
    acc_file = $fopen("tb/psum.txt", "r");
    for (i=0; i<len_nij_unpadded; i=i+1) begin
      for (oc=0; oc<channels; oc=oc+1) begin
        psum_test_q = psum_test;
        acc_scan_file = $fscanf(acc_file,"%32b", psum_test);
        sfu_nij = i;
        sfu_oc = oc;
        sfu_q[1] = 1;
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0; // clock twice to allow sfuout to propagate
        #0.5 clk = 1'b1;
        if (psum_test == sfu_out) begin
          $display("[ OK ] PSUM correct (%4h) for nij=%0d, oc=%0d.", psum_test, i, oc);
        end
        else begin
          $display("[FAIL] PSUM mismatch for nij=%0d, oc=%0d. Expected %4h, got %4h", i, oc, psum_test, sfu_out);
          err = err + 1;
        end
      end
    end
    if (err == 0) $display("[PASS] All PSUM correct.");
    else $display("[FAIL] %0d PSUM incorrect.", err);
    sfu_q[1] = 0;

    $fclose(acc_file);
    /////////////////////////////////////////////////
    for (i=0; i<20; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end
  end

endmodule




