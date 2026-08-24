// Negative: unpacked-structure members retain modport provenance for both a
// direct virtual-interface declaration and one spelled through a typedef.
interface clocking_struct_vif_modport_if(input logic clk);
  logic raw;

  clocking monitor_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking monitor_cb);
endinterface

typedef virtual clocking_struct_vif_modport_if.monitor_mp struct_monitor_vif_t;

typedef struct {
  virtual clocking_struct_vif_modport_if.monitor_mp direct_vif;
  struct_monitor_vif_t typedef_vif;
} clocking_struct_vif_modport_pair_t;

module sv_clocking_struct_vif_modport_raw_member_fail;
  logic clk;
  clocking_struct_vif_modport_if bus(clk);
  clocking_struct_vif_modport_pair_t pair;
  logic direct_observed;
  logic typedef_observed;

  initial begin
    pair.direct_vif = bus;
    pair.typedef_vif = bus;
    direct_observed = pair.direct_vif.raw;
    typedef_observed = pair.typedef_vif.raw;
  end
endmodule
