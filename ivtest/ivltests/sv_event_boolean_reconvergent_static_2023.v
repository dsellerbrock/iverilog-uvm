interface reconv_if; logic [2:0] value; endinterface
class reconv_cfg; virtual reconv_if vif; endclass
module test;
 reconv_if bus(); reconv_cfg cfg; int hits;
 initial begin
  cfg=new; cfg.vif=bus; bus.value=2; #1;
  fork begin @(posedge (bus.value[0] && (bus.value[1] || bus.value[2]))); hits++; end join_none
  #1; bus.value=1;
  #1; bus.value=2;
  #1; if(hits!=0) $fatal(1,"reconvergent fanout fabricated edge hits=%0d",hits);
  bus.value=3;
  #1; if(hits!=1) $fatal(1,"real reconvergent edge missing hits=%0d",hits);
  $display("PASSED reconvergent expression transitions");
 end
endmodule
