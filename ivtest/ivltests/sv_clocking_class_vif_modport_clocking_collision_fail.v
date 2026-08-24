// Negative: exporting a raw member with the same leaf name as a clockvar does
// not export the enclosing clocking block through a class-held VIF.
interface class_mp_clocking_collision_negative_if(input logic clk);
  logic raw;

  clocking hidden_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(input raw);
endinterface

class class_mp_clocking_collision_negative_holder;
  virtual class_mp_clocking_collision_negative_if.monitor_mp vif;
endclass

module sv_clocking_class_vif_modport_clocking_collision_fail;
  logic clk;
  class_mp_clocking_collision_negative_if bus(clk);
  class_mp_clocking_collision_negative_holder holder;
  logic observed;

  initial begin
    holder = new;
    holder.vif = bus;
    observed = holder.vif.hidden_cb.raw;
  end
endmodule
