// Negative: a modport-qualified VIF may not reach a clocking block that the
// selected modport did not export.
interface mp_clocking_unexported_negative_if(input logic clk);
  logic raw;

  clocking visible_cb @(posedge clk);
    input raw;
  endclocking

  clocking hidden_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking visible_cb);
endinterface

module sv_clocking_vif_modport_unexported_clocking_fail;
  logic clk;
  mp_clocking_unexported_negative_if bus(clk);
  virtual mp_clocking_unexported_negative_if.monitor_mp vif;

  initial begin
    vif = bus;
    @(vif.hidden_cb);
    $display("FAILED: unexported clocking block was accessible");
  end
endmodule
