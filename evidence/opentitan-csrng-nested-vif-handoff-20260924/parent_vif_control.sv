interface leaf_if; logic marker; endinterface
interface outer_if; leaf_if nested(); endinterface
class cfg_t; virtual outer_if vif; endclass
module tb;
  outer_if outer();
  cfg_t cfg;
  initial begin
    cfg = new;
    cfg.vif = outer;
    if (cfg.vif == null) $fatal(1, "parent vif null");
    $display("PASS parent vif");
  end
endmodule
