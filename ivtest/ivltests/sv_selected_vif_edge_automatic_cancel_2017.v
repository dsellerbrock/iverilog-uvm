interface automatic_cancel_if; logic [1:0] csb; endinterface
class automatic_cancel_cfg; virtual automatic_cancel_if vif; endclass
class automatic_cancel_dev;
  automatic_cancel_cfg cfg; int index; int id; int wakes;
  function new(input int n); id=n; cfg=new; endfunction
  task automatic wait_pos(input int expected);
    int local_id=id;
    @(posedge cfg.vif.csb[index]);
    if(local_id!=expected || id!=expected) $fatal(1,"automatic context crossed");
    wakes++;
  endtask
endclass
module automatic_cancel;
  automatic_cancel_if bus_a(),bus_b(),bus_k(); automatic_cancel_dev a,b,k;
  initial begin
    bus_a.csb=0;bus_b.csb=0;bus_k.csb=0;
    a=new(1);b=new(2);k=new(3); a.cfg.vif=bus_a;b.cfg.vif=bus_b;k.cfg.vif=bus_k;
    a.index=0;b.index=1;k.index=0;
    fork:a_wait a.wait_pos(1);join_none
    fork:b_wait b.wait_pos(2);join_none
    fork:k_wait k.wait_pos(3);join_none
    #1 disable k_wait;
    bus_a.csb[0]=1;bus_b.csb[1]=1;bus_k.csb[0]=1;
    #1 if(a.wakes!=1||b.wakes!=1||k.wakes!=0) $fatal(1,"automatic/cancel failed");
    $display("PASS automatic cancel");$finish;
  end
endmodule
