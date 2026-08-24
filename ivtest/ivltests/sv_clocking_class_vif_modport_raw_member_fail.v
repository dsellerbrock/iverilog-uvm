// Negative: a clocking-block export does not directly export the raw member
// through a modport-qualified VIF stored in a class property.
interface class_mp_clocking_raw_negative_if(input logic clk);
  logic raw;

  clocking monitor_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking monitor_cb);
endinterface

class class_mp_clocking_raw_negative_holder;
  virtual class_mp_clocking_raw_negative_if.monitor_mp vif;
endclass

module sv_clocking_class_vif_modport_raw_member_fail;
  logic clk;
  class_mp_clocking_raw_negative_if bus(clk);
  class_mp_clocking_raw_negative_holder holder;
  logic observed;

  initial begin
    holder = new;
    holder.vif = bus;
    observed = holder.vif.raw;
  end
endmodule
