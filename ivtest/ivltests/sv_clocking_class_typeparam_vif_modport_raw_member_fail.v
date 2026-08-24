// Negative: both a defaulted type parameter and an explicit type argument
// must preserve a virtual interface's modport qualifier in a class property.
interface clocking_class_typeparam_modport_if(input logic clk);
  logic raw;

  clocking monitor_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking monitor_cb);
endinterface

class clocking_class_typeparam_modport_holder #(
  type VIF = virtual clocking_class_typeparam_modport_if.monitor_mp
);
  VIF vif;
endclass

module sv_clocking_class_typeparam_vif_modport_raw_member_fail;
  logic clk;
  clocking_class_typeparam_modport_if bus(clk);
  clocking_class_typeparam_modport_holder default_holder;
  clocking_class_typeparam_modport_holder #(
    virtual clocking_class_typeparam_modport_if.monitor_mp
  ) actual_holder;
  logic default_observed;
  logic actual_observed;

  initial begin
    default_holder = new;
    actual_holder = new;
    default_holder.vif = bus;
    actual_holder.vif = bus;
    default_observed = default_holder.vif.raw;
    actual_observed = actual_holder.vif.raw;
  end
endmodule
