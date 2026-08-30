// NEG-DIAG: An interface instance may be compared only with a same-type virtual interface using == or != (IEEE 1800-2017/2023 25.9).
// NEG-DIAG-COUNT: 2
// IEEE 1800-2017/2023 25.9 permits a concrete interface instance as the
// counterpart of a same-type virtual-interface operand. Two concrete
// interface instances are scopes, not standalone comparison expressions.
interface vif_comparison_concrete_negative_if;
endinterface

module vif_comparison_concrete_instances;
  vif_comparison_concrete_negative_if first();
  vif_comparison_concrete_negative_if second();
  logic observed;

  initial begin
    observed = (first == second);
    observed = (second != first);
  end
endmodule
