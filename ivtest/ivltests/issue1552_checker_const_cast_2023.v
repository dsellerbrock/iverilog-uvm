checker procedural_checker(logic x);
  logic stored;
  initial stored = x;
endchecker

checker continuous_checker(logic x);
  logic stored;
  assign stored = x;
endchecker

checker assertion_checker(logic x);
  assert property (@(posedge x) x == 1'b1);
endchecker

module issue1552_checker_const_cast;
  logic a = 1'b1;
  procedural_checker proc_i(const'(a));
  continuous_checker cont_i(const'(a));
  assertion_checker assertion_i(const'(a));
endmodule
