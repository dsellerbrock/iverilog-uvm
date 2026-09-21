interface vif_t; logic [1:0] reset_cause; endinterface
class cfg_t; virtual vif_t vif; endclass
class scoreboard_t;
  cfg_t cfg; int hits;
  task collector(); @(posedge (cfg.vif.reset_cause == 2'b10)); hits++; endtask
endclass
module top;
 vif_t physical(); scoreboard_t sb; cfg_t cfg;
 initial begin
   sb=new; cfg=new; cfg.vif=physical; sb.cfg=cfg;
   fork sb.collector(); begin #1; physical.reset_cause=2'b10; end join
   if(sb.hits!=1) $fatal(1,"FAIL hits=%0d",sb.hits);
   $display("PASS direct task VIF event hits=%0d",sb.hits);
 end
endmodule
