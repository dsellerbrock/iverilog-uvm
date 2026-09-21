interface ev_if; logic [1:0] sig; endinterface
class cfg_t; virtual ev_if vif; endclass
class watcher_t;
  cfg_t cfg; int old_hits, new_hits;
  task spawn_old(); fork begin @(posedge (cfg.vif.sig == 2'b10)); old_hits++; end join_none endtask
  task spawn_new(); fork begin @(posedge (cfg.vif.sig == 2'b10)); new_hits++; end join_none endtask
endclass
module top;
  ev_if old_if(), new_if(); cfg_t cfg; watcher_t w;
  initial begin
    cfg=new; w=new; cfg.vif=old_if; w.cfg=cfg;
    w.spawn_old(); #1; old_if.sig=2'b10; #1; old_if.sig=2'b00;
    cfg.vif=new_if;
    w.spawn_new(); #1; old_if.sig=2'b10; #1;
    if (w.new_hits!=0) $fatal(1,"old source retained new_hits=%0d",w.new_hits);
    new_if.sig=2'b10; #1;
    if (w.old_hits!=1 || w.new_hits!=1) $fatal(1,"FAIL old=%0d new=%0d",w.old_hits,w.new_hits);
    $display("PASS descendant after rebind old=%0d new=%0d",w.old_hits,w.new_hits);
  end
endmodule
