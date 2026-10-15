module sv_assert_multiclock_disable_branch_unsupported_2023;
  reg c1 = 0, c2 = 0, c3 = 0;
  reg a = 0, b = 0, c = 0, d = 0, e = 0, f = 0, rst_n = 1;

  assert property (@(posedge c1) disable iff (!rst_n)
                   ((a ##1 b) and (c ##1 d)) |->
                   @(posedge c2) e ##1 @(posedge c3) f)
  else $error("unsupported branched antecedent must be diagnosed");
endmodule
