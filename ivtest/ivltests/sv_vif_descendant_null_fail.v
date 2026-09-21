interface ev_if; logic [1:0] sig; endinterface
class cfg_t; virtual ev_if vif; endclass
class watcher_t;
  cfg_t cfg;
  task spawn_wait(); fork begin @(posedge (cfg.vif.sig == 2'b10)); $fatal(1,"null wait body ran"); end join_none endtask
endclass
module top;
  cfg_t cfg; watcher_t w;
  initial begin
    cfg=new; w=new; w.cfg=cfg;
    w.spawn_wait(); #1;
    $fatal(1,"null event arm was accepted");
  end
endmodule
