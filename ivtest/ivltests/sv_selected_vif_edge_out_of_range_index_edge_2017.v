interface out_of_range_index_edge_if; logic [1:0] csb; endinterface
class out_of_range_index_edge_cfg; virtual out_of_range_index_edge_if vif; endclass
class out_of_range_index_edge_dev;
  out_of_range_index_edge_cfg cfg; integer index; int pos_wakes; int neg_wakes;
  task automatic wait_pos; @(posedge cfg.vif.csb[index]); pos_wakes++; endtask
  task automatic wait_neg; @(negedge cfg.vif.csb[index]); neg_wakes++; endtask
endclass
module out_of_range_index_edge;
  out_of_range_index_edge_if bus(); out_of_range_index_edge_dev d;
  initial begin
    bus.csb=2'b10;d=new;d.cfg=new;d.cfg.vif=bus;d.index=0;
    fork d.wait_pos(); join_none
    #1 d.index=-1; // 0 -> X: posedge
    #1 if(d.pos_wakes!=1) $fatal(1,"0-X negative OOB posedge missed");
    fork d.wait_pos(); join_none
    #1 d.index=9; // X -> X: no edge
    #1 if(d.pos_wakes!=1) $fatal(1,"equal-X positive OOB woke posedge");
    d.index=1; // X -> 1: posedge
    #1 if(d.pos_wakes!=2) $fatal(1,"X-1 OOB recovery posedge missed");
    fork d.wait_neg(); join_none
    #1 d.index=-1; // 1 -> X: negedge
    #1 if(d.neg_wakes!=1) $fatal(1,"1-X negative OOB negedge missed");
    fork d.wait_neg(); join_none
    #1 d.index=9; // X -> X: no edge
    #1 if(d.neg_wakes!=1) $fatal(1,"equal-X positive OOB woke negedge");
    d.index=0; // X -> 0: negedge
    #1 if(d.neg_wakes!=2) $fatal(1,"X-0 OOB recovery negedge missed");
    $display("PASS out of range index edge");$finish;
  end
endmodule
