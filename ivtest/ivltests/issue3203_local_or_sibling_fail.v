// Issue #3203: IEEE 1800-2017/2023 16.10, F.5.4. A local variable assigned
// in one operand of `or' is unassigned in the sibling operand, so the
// reference there is illegal.
module top;
  logic clk, a, b, c, d, e, data;
  sequence bad;
    int x;
    (a ##1 (b, x = data) ##1 c) or (d ##1 (e && (x == data)));
  endsequence
  assert property (@(posedge clk) bad);
endmodule
