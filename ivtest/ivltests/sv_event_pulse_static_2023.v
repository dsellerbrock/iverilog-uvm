interface pulse_if; logic [1:0] value; endinterface
class pulse_cfg; virtual pulse_if vif; endclass
module test;
 pulse_if bus(); pulse_cfg cfg; int hits;
 initial begin
  cfg=new; cfg.vif=bus; bus.value=0; #1;
  fork begin @(posedge (|bus.value)); hits++; end join_none
  #1; bus.value=1; bus.value=0;
  #1; if(hits!=1) $fatal(1,"same-slot pulse lost hits=%0d",hits);
  $display("PASSED captured same-slot pulse");
 end
endmodule
