// NEG-DIAG: Virtual-interface comparison operands must have the same type (IEEE 1800-2017/2023 25.9).
// NEG-DIAG-COUNT: 2
// IEEE 1800-2017/2023 25.9 restricts virtual-interface equality operands to
// the same interface type. Distinct interface definitions are incompatible
// even when their declarations have identical contents.
interface vif_comparison_different_negative_a_if;
endinterface

interface vif_comparison_different_negative_b_if;
endinterface

module vif_comparison_different_interfaces;
  vif_comparison_different_negative_a_if first();
  vif_comparison_different_negative_b_if second();
  virtual interface vif_comparison_different_negative_a_if lhs;
  virtual interface vif_comparison_different_negative_b_if rhs;
  logic observed;

  initial begin
    lhs = first;
    rhs = second;
    observed = (lhs == rhs);
    observed = (rhs != lhs);
  end
endmodule
