interface ordinary_vif_control_if; logic [2:0] csb; endinterface
module ordinary_vif_control;
  ordinary_vif_control_if bus(); int index; int wakes;
  initial begin
    bus.csb=0;index=2;
    fork begin @(posedge bus.csb[index]); wakes++; end join_none
    #1 bus.csb[1]=1;
    #1 if(wakes!=0) $fatal(1,"ordinary nonselected bit woke");
    bus.csb[2]=1;
    #1 if(wakes!=1) $fatal(1,"ordinary selected bit missed");
    $display("PASS ordinary VIF control");$finish;
  end
endmodule
