// Negative: a typedef must retain the modport qualifier of its virtual-
// interface type. The raw signal is intentionally absent from monitor_mp.
interface clocking_vif_modport_typedef_if(input logic clk);
  logic raw;

  clocking monitor_cb @(posedge clk);
    input raw;
  endclocking

  modport monitor_mp(clocking monitor_cb);
endinterface

module sv_clocking_vif_modport_typedef_raw_member_fail;
  logic clk;
  clocking_vif_modport_typedef_if bus(clk);
  typedef virtual clocking_vif_modport_typedef_if.monitor_mp monitor_vif_t;
  monitor_vif_t vif;
  logic observed;

  initial begin
    vif = bus;
    observed = vif.raw;
  end
endmodule
