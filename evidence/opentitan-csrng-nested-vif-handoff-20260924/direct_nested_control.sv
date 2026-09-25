interface leaf_if; logic marker; endinterface
interface outer_if; leaf_if nested(); endinterface
class sink_t;
  virtual leaf_if vif;
  function void put(virtual leaf_if value); vif = value; endfunction
endclass
module tb;
  outer_if outer();
  sink_t sink;
  initial begin
    sink = new;
    sink.put(outer.nested);
    if (sink.vif == null) $fatal(1, "direct child null");
    $display("PASS direct child");
  end
endmodule
