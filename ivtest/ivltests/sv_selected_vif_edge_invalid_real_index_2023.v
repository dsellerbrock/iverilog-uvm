interface invalid_real_index_if; logic [1:0] csb; endinterface
class invalid_real_index_cfg; virtual invalid_real_index_if vif; endclass
class invalid_real_index_dev;
  invalid_real_index_cfg cfg; real index;
  task automatic wait_pos; @(posedge cfg.vif.csb[index]); endtask
endclass
module invalid_real_index;
  invalid_real_index_if bus(); invalid_real_index_dev d;
  initial begin d=new;d.cfg=new;d.cfg.vif=bus;d.wait_pos();end
endmodule
