// IEEE 1800-2017/2023 25.9 forbids assigning an interface instance to a
// virtual interface when an external defparam changes a parameter of that
// instance or its interface hierarchy. A defparam declared within the
// interface remains a legal control.
module param_vif_defparam_leaf #(parameter int OFFSET = 0);
endmodule

interface param_vif_defparam_if #(parameter int WIDTH = 8);
  param_vif_defparam_leaf leaf_i();
  defparam leaf_i.OFFSET = WIDTH;
  logic [WIDTH-1:0] data;
endinterface

module sv_vif_parameter_specialization_defparam_fail;
  param_vif_defparam_if internal_only();
  param_vif_defparam_if external_root();
  param_vif_defparam_if external_nested();

  defparam external_root.WIDTH = 16;
  defparam external_nested.leaf_i.OFFSET = 17;

  virtual interface param_vif_defparam_if internal_vif;
  virtual interface param_vif_defparam_if #(16) root_vif;
  virtual interface param_vif_defparam_if nested_vif;
  logic observed;

  initial begin
    // Legal control: the only defparam in this hierarchy is declared inside
    // the interface, and therefore applies uniformly to its instances.
    internal_vif = internal_only;

    // Illegal even though the VIF parameter value matches the effective root.
    root_vif = external_root;

    // The restriction covers a parameter below the root interface instance.
    nested_vif = external_nested;

    // Equality is not a transfer into the VIF handle. Same-full-type concrete
    // instances remain legal comparison operands even when an external
    // defparam makes them ineligible as assignment sources.
    observed = (root_vif == external_root);
    observed = (nested_vif != external_nested);
  end
endmodule
