// The edge-qualified companion to sv_vif_null_anyedge_fail.
interface vif_null_posedge_if;
  logic signal;
endinterface

module sv_vif_null_posedge_fail;
  virtual vif_null_posedge_if vif;
  initial @(posedge vif.signal);
endmodule
