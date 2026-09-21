interface atomic_if; logic [1:0] value; endinterface
class atomic_cfg; virtual atomic_if vif; endclass
module test;
 atomic_if bus(); atomic_cfg cfg; int hits;
 initial begin
  cfg=new; cfg.vif=bus; bus.value=1; #1;
  fork begin @(posedge (bus.value[0] && bus.value[1])); hits++; end join_none
  #1; bus.value=2;
  #1; bus.value=1;
  #1; if(hits!=0) $fatal(1,"atomic assignment fabricated edge hits=%0d",hits);
  bus.value=3;
  #1; if(hits!=1) $fatal(1,"real edge missing hits=%0d",hits);
  $display("PASSED atomic expression transitions");
 end
endmodule
