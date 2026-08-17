// IEEE 1800-2017 25.9 requires a fatal run-time error when a null virtual
// interface is used. This is the reduced Caliptra crash shape.
interface vif_null_anyedge_if;
  logic signal;
endinterface

module sv_vif_null_anyedge_fail;
  virtual vif_null_anyedge_if vif;

  // Pin process-global fatal handling: both processes are runnable at time
  // zero, but one invalid simulation condition must produce one diagnostic.
  initial @(vif.signal);
  initial @(vif.signal);
endmodule
