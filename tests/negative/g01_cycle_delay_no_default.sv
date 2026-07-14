// IEEE 1800-2017 14.11: a procedural cycle delay requires a default
// clocking block in scope. Must produce an error, not hang or ignore.
module top;
  logic clk = 0;
  initial begin
    ##1;
  end
endmodule
