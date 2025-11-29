module sram #(
    parameter WIDTH = 32,
    parameter DEPTH = 2048,
    parameter ADDR_BITS = 11
)(
    input  CLK,
    input  CEN, // 0 = enable
    input  WEN, // 0 = write, 1 = read
    input  [WIDTH-1:0] D,
    input  [ADDR_BITS-1:0] A,
    output [WIDTH-1:0] Q
);

    reg [WIDTH-1:0] memory [0:DEPTH-1];
    reg [ADDR_BITS-1:0] addr_reg;

    assign Q = memory[addr_reg];

    always @(posedge CLK) begin
        if (!CEN && WEN) begin
            // read
            addr_reg <= A;
        end
        else if (!CEN && !WEN) begin
            // write
            memory[A] <= D;
        end
    end

endmodule
