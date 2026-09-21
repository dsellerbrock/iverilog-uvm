interface ev_if; logic [1:0] sig; endinterface
class cfg_t; virtual ev_if vif; endclass
class watcher_t;
  cfg_t cfg; int hits;
  task spawn_wait();
    fork begin
      fork begin @(posedge (cfg.vif.sig == 2'b10)); hits++; end join_none
    end join_none
  endtask
endclass
module top;
  ev_if physical(); cfg_t cfg; watcher_t w;
  initial begin
    cfg=new; w=new; cfg.vif=physical; w.cfg=cfg;
    w.spawn_wait(); #1; physical.sig=2'b10; #1;
    if(w.hits!=1) $fatal(1,"FAIL hits=%0d",w.hits);
    $display("PASS two-level descendant hits=%0d",w.hits);
  end
endmodule
