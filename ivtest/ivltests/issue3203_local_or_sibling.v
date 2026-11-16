// Issue #3203 controls (IEEE 1800-2017/2023 16.10): each `or' operand
// assigns the local before reading it; an initialized local may be read in
// either operand; an antecedent's assignment flows into the consequent.
module top;
  logic clk = 0, a = 1, b = 1, c = 1, d = 1, e = 1, data = 0;
  always #5 clk = ~clk;
  sequence ok_both;
    int x;
    (a ##1 (b, x = data) ##1 (c && x == data))
      or (d ##1 (e, x = data) ##1 (x == data));
  endsequence
  sequence ok_init;
    int y = 0;
    (a ##1 (b, y = 1)) or (d ##1 (y == 0));
  endsequence
  property ok_impl;
    int z;
    (a, z = data) |-> ##1 (z == data);
  endproperty
  assert property (@(posedge clk) ok_both);
  assert property (@(posedge clk) ok_init);
  assert property (@(posedge clk) ok_impl);
  initial begin #30 $display("PASSED"); $finish; end
endmodule
