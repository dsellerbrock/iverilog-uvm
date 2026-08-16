// A compound dynamic event still attempts to use every referenced virtual
// interface and therefore must fail when its handle is null.
interface vif_null_multi_if;
  logic first;
  logic second;
endinterface

module sv_vif_null_multi_fail;
  virtual vif_null_multi_if vif;
  initial @(vif.first or vif.second);
endmodule
