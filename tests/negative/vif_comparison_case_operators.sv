// NEG-DIAG: Virtual interfaces support only == and != comparisons (IEEE 1800-2017/2023 25.9).
// NEG-DIAG-COUNT: 2
// IEEE 1800-2017/2023 25.9 lists logical equality and inequality as the
// comparison operations for virtual interfaces. Case equality and case
// inequality are not virtual-interface operations and must fail directly.
interface vif_comparison_case_negative_if;
endinterface

module vif_comparison_case_operators;
  vif_comparison_case_negative_if first();
  vif_comparison_case_negative_if second();
  virtual interface vif_comparison_case_negative_if lhs;
  virtual interface vif_comparison_case_negative_if rhs;
  logic observed;

  initial begin
    lhs = first;
    rhs = second;
    observed = (lhs === rhs);
    observed = (lhs !== null);
  end
endmodule
