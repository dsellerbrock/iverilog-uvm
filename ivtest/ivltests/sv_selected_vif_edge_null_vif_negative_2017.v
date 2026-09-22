interface null_vif_negative_if; logic [1:0] csb; endinterface
class null_vif_negative_cfg; virtual null_vif_negative_if vif; endclass
class null_vif_negative_dev;
  null_vif_negative_cfg cfg; int index;
  task automatic wait_pos;
    @(posedge cfg.vif.csb[index]);
    $display("ILLEGAL_AFTER_NULL_VIF");
  endtask
endclass
module null_vif_negative;
  null_vif_negative_dev d;
  initial begin
    d=new;d.cfg=new;d.cfg.vif=null;d.index=0;
    d.wait_pos();
    $display("ILLEGAL_AFTER_NULL_ERROR");
  end
endmodule
