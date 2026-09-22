interface null_rebind_negative_if; logic [1:0] csb; endinterface
class null_rebind_negative_cfg; virtual null_rebind_negative_if vif; endclass
class null_rebind_negative_dev;
  null_rebind_negative_cfg cfg; int index;
  task automatic wait_pos;
    @(posedge cfg.vif.csb[index]);
    $display("ILLEGAL_AFTER_NULL_REBIND_EVENT");
  endtask
endclass
module null_rebind_negative;
  null_rebind_negative_if bus(); null_rebind_negative_dev d;
  initial begin
    bus.csb=0;d=new;d.cfg=new;d.cfg.vif=bus;d.index=0;
    fork d.wait_pos(); join_none
    #1 d.cfg.vif=null;
    #1 $display("ILLEGAL_AFTER_NULL_REBIND_ERROR");
  end
endmodule
