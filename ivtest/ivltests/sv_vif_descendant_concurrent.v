interface ev_if; logic [1:0] sig; endinterface
class cfg_t; virtual ev_if vif; endclass
class watcher_t;
  cfg_t cfg; int hits;
  task spawn_wait(); fork begin @(posedge (cfg.vif.sig == 2'b10)); hits++; end join_none endtask
endclass
module top;
  ev_if a(), b(); cfg_t ca, cb; watcher_t wa, wb;
  initial begin
    ca=new; cb=new; wa=new; wb=new;
    ca.vif=a; cb.vif=b; wa.cfg=ca; wb.cfg=cb;
    wa.spawn_wait(); wb.spawn_wait();
    #1; a.sig=2'b10; b.sig=2'b10; #1;
    if (wa.hits!=1 || wb.hits!=1) $fatal(1,"FAIL a=%0d b=%0d",wa.hits,wb.hits);
    $display("PASS concurrent distinct roots a=%0d b=%0d",wa.hits,wb.hits);
  end
endmodule
