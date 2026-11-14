// IEEE 1800-2023 17.3: "It shall be illegal to instantiate checkers in
// fork-join, fork-join_any, or fork-join_none blocks" and "to instantiate a
// checker in a procedure of another checker"; only a checker may be
// instantiated in procedural code.
checker ck(event clk, logic a);
  p: assert property (@clk a);
endchecker

checker outer(event clk, logic a);
  always_ff @(clk) begin
    ck inner(clk, a);
  end
endchecker

module mod_t(input logic a);
endmodule

module top;
  logic clk = 0, a = 0;
  initial fork
    ck in_fork(posedge clk, a);
  join
  always @(posedge clk) begin
    mod_t m1(a);
  end
endmodule
