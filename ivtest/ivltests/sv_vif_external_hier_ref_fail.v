// IEEE 1800-2017/2023 25.9 prohibits virtual interfaces to interfaces with
// outside hierarchical references or ports referencing other interfaces.
interface sv_vif_external_hier_ref_if;
  logic x;
  assign x = sv_vif_external_hier_ref_top.g;
endinterface

interface sv_vif_external_hier_ref_nested_if;
  logic y;
endinterface

interface sv_vif_external_hier_ref_port_if(sv_vif_external_hier_ref_nested_if nested);
endinterface

module sv_vif_external_hier_ref_top;
  logic g = 1'b1;
  sv_vif_external_hier_ref_if bus();
  sv_vif_external_hier_ref_nested_if nested_bus();
  sv_vif_external_hier_ref_port_if port_bus(nested_bus);
  virtual sv_vif_external_hier_ref_if vif;
  virtual sv_vif_external_hier_ref_port_if port_vif;
endmodule
