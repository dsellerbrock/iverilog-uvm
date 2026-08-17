// The negative-edge companion to sv_vif_null_anyedge_fail.
interface vif_null_negedge_if;
  logic signal;
endinterface

module sv_vif_null_negedge_fail;
  virtual vif_null_negedge_if vif;
  initial @(negedge vif.signal);
endmodule
