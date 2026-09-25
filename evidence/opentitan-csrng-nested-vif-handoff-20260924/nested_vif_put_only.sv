interface leaf_if;
  logic marker;
endinterface
interface outer_if;
  leaf_if nested();
endinterface
class cfg_t;
  virtual outer_if vif;
endclass
class sink_t;
  virtual leaf_if vif;
  function void put(virtual leaf_if value);
    vif = value;
  endfunction
endclass
module tb;
  outer_if outer();
  cfg_t cfg;
  sink_t sink;
  initial begin
    cfg = new;
    sink = new;
    cfg.vif = outer;
    sink.put(cfg.vif.nested);
    $display("PASS nested interface handoff");
  end
endmodule
