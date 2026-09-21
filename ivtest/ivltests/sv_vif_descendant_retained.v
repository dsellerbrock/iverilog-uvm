interface vif_t;
  logic [1:0] reset_cause;
  logic [9:0] slow_state;
endinterface
class cfg_t; virtual vif_t vif; endclass
class scoreboard_t;
  cfg_t cfg; int hw_hits, slow_hits;
  task reset_coverage_collector();
    fork
      begin @(posedge (cfg.vif.reset_cause == 2'b10)); hw_hits++; end
      begin @(posedge (cfg.vif.slow_state == 10'h287)); slow_hits++; end
    join_none
    #3; // Retain the automatic task activation while children arm and wake.
  endtask
endclass
module top;
  vif_t physical(); scoreboard_t sb; cfg_t cfg;
  initial begin
    sb=new; cfg=new; cfg.vif=physical; sb.cfg=cfg;
    fork
      sb.reset_coverage_collector();
      begin #1; physical.reset_cause=2'b10; physical.slow_state=10'h287; end
    join
    if (sb.hw_hits != 1 || sb.slow_hits != 1) $fatal(1,"FAIL hw=%0d slow=%0d",sb.hw_hits,sb.slow_hits);
    $display("PASS retained task VIF events hw=%0d slow=%0d",sb.hw_hits,sb.slow_hits);
  end
endmodule
