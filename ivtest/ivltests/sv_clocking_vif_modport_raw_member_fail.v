// Negative: exporting a clocking block does not directly export the raw
// interface member. This source identifier has no compiler provenance and
// must fail the ordinary modport visibility check.
interface mp_clocking_raw_negative_if(input logic clk);
  logic raw;

  clocking monitor_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking monitor_cb);
endinterface

module sv_clocking_vif_modport_raw_member_fail;
  logic clk;
  mp_clocking_raw_negative_if bus(clk);
  virtual mp_clocking_raw_negative_if.monitor_mp vif;
  logic observed;

  initial begin
    vif = bus;
    observed = vif.raw;
  end
endmodule
