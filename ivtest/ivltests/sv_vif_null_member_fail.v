// IEEE 1800-2017/2023 25.9 requires a fatal run-time error when a component
// of a null virtual interface is referenced.
interface vif_null_member_if;
  logic a;
endinterface

module sv_vif_null_member_fail;
  virtual vif_null_member_if vif;

  initial begin
    vif.a = 1'b1;
    $display("SURVIVED");
  end
endmodule
