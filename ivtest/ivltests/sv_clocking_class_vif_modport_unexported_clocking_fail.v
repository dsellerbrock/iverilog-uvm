// Negative: a class-held modport-qualified VIF may not reach a clocking block
// that the selected modport did not export.
interface class_mp_clocking_unexported_negative_if(input logic clk);
  logic raw;

  clocking visible_cb @(posedge clk);
    input raw;
  endclocking

  clocking hidden_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking visible_cb);
endinterface

class class_mp_clocking_unexported_negative_holder;
  virtual class_mp_clocking_unexported_negative_if.monitor_mp vif;
endclass

module sv_clocking_class_vif_modport_unexported_clocking_fail;
  logic clk;
  class_mp_clocking_unexported_negative_if bus(clk);
  class_mp_clocking_unexported_negative_holder holder;

  initial begin
    holder = new;
    holder.vif = bus;
    @(holder.vif.hidden_cb);
    $display("FAILED: class-held VIF reached an unexported clocking block");
  end
endmodule
