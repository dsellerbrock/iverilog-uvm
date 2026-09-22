interface four_state_edges_if;
  logic [1:0] csb;
endinterface
class four_state_edges_cfg; virtual four_state_edges_if vif; endclass
class four_state_edges_dev;
  four_state_edges_cfg cfg; int index; int pos_wakes; int neg_wakes;
  task automatic wait_pos; @(posedge cfg.vif.csb[index]); pos_wakes++; endtask
  task automatic wait_neg; @(negedge cfg.vif.csb[index]); neg_wakes++; endtask
endclass
module four_state_edges;
  four_state_edges_if bus(); four_state_edges_dev d;
  initial begin
    bus.csb=0; d=new; d.cfg=new; d.cfg.vif=bus; d.index=1;
    fork d.wait_pos(); join_none
    #1 bus.csb[1]=1'bx;
    #1 if(d.pos_wakes!=1) $fatal(1,"0-X posedge missed");
    bus.csb[1]=1'bz;
    fork d.wait_pos(); join_none
    #1 bus.csb[1]=1'b1;
    #1 if(d.pos_wakes!=2) $fatal(1,"Z-1 posedge missed");
    fork d.wait_neg(); join_none
    #1 bus.csb[1]=1'bx;
    #1 if(d.neg_wakes!=1) $fatal(1,"1-X negedge missed");
    bus.csb[1]=1'bz;
    fork d.wait_neg(); join_none
    #1 bus.csb[1]=1'b0;
    #1 if(d.neg_wakes!=2) $fatal(1,"Z-0 negedge missed");
    $display("PASS four state edges"); $finish;
  end
endmodule
