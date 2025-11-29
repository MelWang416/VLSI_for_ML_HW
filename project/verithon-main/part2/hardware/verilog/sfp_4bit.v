module sfp_4bit #(
    parameter col = 8,
    parameter psum_bw = 16,
    parameter act_bw  = 4
)(
    input                     clk,
    input                     reset,

    // From MAC array
    input  [col*psum_bw-1:0]  mac_psum,
    input  [col-1:0]          mac_valid,

    // Old psum from psum SRAM (if accumulation is needed)
    input  [col*psum_bw-1:0]  old_psum,
    input                     old_psum_valid,

    // Outputs TO psum SRAM (write-back)
    output [col*psum_bw-1:0]  new_psum,
    output [col-1:0]          new_psum_we,

    // Outputs TO OFIFO
    output [col*act_bw-1:0]   act_out,
    output [col-1:0]          act_valid
);

    genvar i;
    generate
        for (i = 0; i < col; i = i + 1) begin : sfp_col

            // Slice psums
            wire [psum_bw-1:0] mac_p   = mac_psum[(i+1)*psum_bw-1 : i*psum_bw];
            wire [psum_bw-1:0] old_p   = old_psum[(i+1)*psum_bw-1 : i*psum_bw];

            // 1) ACCUMULATION
            wire [psum_bw-1:0] acc_p   = mac_p + old_p;

            // 2) RELU (simple: clamp negative to zero)
            wire [psum_bw-1:0] relu_p  = acc_p[psum_bw-1] ? {psum_bw{1'b0}} : acc_p;

            // 3) Qantization (truncate higher bits)
            // Example: take top 4 bits of the 16-bit ReLU output
            wire [act_bw-1:0] quant_p = relu_p[psum_bw-1 -: act_bw];

            // Output activation
            assign act_out[(i+1)*act_bw-1 : i*act_bw] = quant_p;

            // Valid signals propagate from MAC
            assign act_valid[i] = mac_valid[i] & old_psum_valid;

            // psum write-back (used for next accumulation cycle)
            assign new_psum[(i+1)*psum_bw-1 : i*psum_bw] = acc_p;
            assign new_psum_we[i] = mac_valid[i];

        end
    endgenerate

endmodule
