module genuine_async_load(input clk, input rst_n, input [7:0] d,
                           output reg [7:0] q);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= d;
    else q <= q + 1'b1;
endmodule
