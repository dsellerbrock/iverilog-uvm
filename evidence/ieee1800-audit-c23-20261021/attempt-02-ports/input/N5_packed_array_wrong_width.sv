module dff(output logic q, input logic d, input logic clk);
    always @(posedge clk) q <= d;
endmodule

module top;
    logic [4:0] Q;
    logic [3:0] D = 4'b1010;
    logic clk = 0;
    dff u[3:0](Q, D, clk);
endmodule
