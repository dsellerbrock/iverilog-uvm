// NEG-DIAG: A virtual interface may be compared only with null, a same-type virtual interface, or a same-type interface instance (IEEE 1800-2017/2023 25.9).
// NEG-DIAG-COUNT: 1
// A block-local object must shadow an outer interface-instance array before
// virtual-interface comparison dispatch examines a runtime index.
interface vif_comparison_shadowed_array_if;
endinterface

module vif_comparison_shadowed_instance_array;
  vif_comparison_shadowed_array_if pins[2]();
  virtual interface vif_comparison_shadowed_array_if vif;
  int index;
  logic observed;

  initial begin
    vif = pins[0];
    begin : shadow
      int pins[2];
      index = 0;
      observed = (vif == pins[index]);
    end
  end
endmodule
