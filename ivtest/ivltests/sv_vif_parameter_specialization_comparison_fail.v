// IEEE 1800-2017/2023 25.9: unlike assignment, virtual-interface == and !=
// require identical complete interface types. Parameter specialization and
// selected modport are both part of that type; there is no one-way relaxation.
interface param_vif_compare_if #(parameter WIDTH = 8);
  logic [WIDTH-1:0] data;
  modport phy(input data);
endinterface

module sv_vif_parameter_specialization_comparison_fail;
  param_vif_compare_if #(16) p16_a();
  param_vif_compare_if #(.WIDTH(16)) p16_b();
  param_vif_compare_if #(32) p32();

  virtual interface param_vif_compare_if #(16) v16_a;
  virtual interface param_vif_compare_if #(.WIDTH(16)) v16_b;
  virtual interface param_vif_compare_if #(32) v32;
  virtual interface param_vif_compare_if #(16).phy v16_phy;
  logic observed;

  initial begin
    v16_a = p16_a;
    v16_b = p16_b;
    v32 = p32;
    v16_phy = p16_a.phy;

    // Same full type is legal even when the concrete instances differ.
    observed = (v16_a == p16_a);
    observed = (v16_a != v16_b);
    observed = (v16_phy == p16_a.phy);

    // Parameter-specialization mismatches.
    observed = (v16_a == v32);
    observed = (v16_a != p32);

    // Modport-selected and unselected VIF types are not comparison-compatible.
    observed = (v16_a == v16_phy);
    observed = (v16_phy != v16_a);

    // The assignment-only unselected-source relaxation does not apply here.
    observed = (v16_phy == p16_a);
  end
endmodule
