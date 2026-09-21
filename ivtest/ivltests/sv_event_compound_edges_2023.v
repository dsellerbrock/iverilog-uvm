interface event_if;
  logic [1:0] wake;
  logic state;
  logic [1:0] req;
endinterface
class configuration;
  virtual event_if vif;
endclass
module test;
  event_if signals();
  configuration cfg;
  int raw_count, reduction_count, predicate_count, negedge_count;
  initial begin
    signals.wake=0; signals.state=0; signals.req=2'b10;
    cfg=new; cfg.vif=signals;
    fork
      repeat(3) begin @(cfg.vif.wake); raw_count++; end
      repeat(2) begin @(posedge (|cfg.vif.wake)); reduction_count++; end
      begin @(posedge (cfg.vif.state == 1'b1)); predicate_count++; end
      begin @(negedge cfg.vif.req[1]); negedge_count++; end
    join_none
    #1;
    if(raw_count || reduction_count || predicate_count || negedge_count)
      $fatal(1,"event wait skipped: %0d %0d %0d %0d",raw_count,reduction_count,predicate_count,negedge_count);
    signals.wake=2'b10; signals.state=1; signals.req=0;
    #1;
    if(raw_count!=1 || reduction_count!=1 || predicate_count!=1 || negedge_count!=1) $fatal(1,"first edges");
    signals.wake=2'b11;
    #1;
    if(raw_count!=2 || reduction_count!=1) $fatal(1,"operand change is not expression edge");
    signals.wake=0; #1; signals.wake=1; #1;
    if(raw_count!=3 || reduction_count!=2) $fatal(1,"rearmed edges");
    $display("PASSED");
  end
endmodule
