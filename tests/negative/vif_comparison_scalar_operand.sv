// NEG-DIAG: A virtual interface may be compared only with null, a same-type virtual interface, or a same-type interface instance (IEEE 1800-2017/2023 25.9).
// NEG-DIAG-COUNT: 2
// IEEE 1800-2017/2023 25.9 does not permit a scalar as either operand of a
// virtual-interface comparison. The virtual-interface type context must not
// convert an ordinary scalar expression into a null-handle fallback.
interface vif_comparison_scalar_negative_if;
endinterface

module vif_comparison_scalar_operand;
  vif_comparison_scalar_negative_if bus();
  virtual interface vif_comparison_scalar_negative_if vif;
  int scalar;
  logic observed;

  initial begin
    vif = bus;
    observed = (vif == scalar);
    observed = (scalar != vif);
  end
endmodule
