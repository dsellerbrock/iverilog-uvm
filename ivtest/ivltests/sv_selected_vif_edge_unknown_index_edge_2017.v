interface unknown_index_edge_if; logic [3:0] csb; endinterface
class unknown_index_edge_cfg; virtual unknown_index_edge_if vif; endclass
class unknown_index_edge_dev;
  unknown_index_edge_cfg cfg; logic [1:0] index; int wakes;
  task automatic wait_pos; @(posedge cfg.vif.csb[index]); wakes++; endtask
endclass
module unknown_index_edge;
  unknown_index_edge_if bus(); unknown_index_edge_dev d;
  initial begin
    bus.csb=0;d=new;d.cfg=new;d.cfg.vif=bus;d.index=0;
    fork d.wait_pos(); join_none
    #1 d.index=2'bxx; // bit-select result changes 0 -> X, a posedge by Table 9-2
    #1 if(d.wakes!=1) $fatal(1,"0-X from unknown index missed");
    $display("PASS unknown index edge");$finish;
  end
endmodule
