interface dynamic_index_if;
  logic [1:0] csb;
endinterface
class dynamic_index_cfg; virtual dynamic_index_if vif; endclass
class dynamic_index_dev;
  dynamic_index_cfg cfg;
  logic active_csb;
  int wakes;
  task automatic wait_pos;
    @(posedge cfg.vif.csb[active_csb]);
    wakes++;
  endtask
endclass
module dynamic_index;
  dynamic_index_if bus(); dynamic_index_dev d;
  initial begin
    bus.csb = 2'b10;
    d = new; d.cfg = new; d.cfg.vif = bus; d.active_csb = 0;
    fork d.wait_pos(); join_none
    #1 d.active_csb = 1; // selected expression changes 0 -> 1
    #1 if (d.wakes != 1) $fatal(1, "index-induced posedge missed");
    fork d.wait_pos(); join_none
    #1 d.active_csb = 0; // selected expression changes 1 -> 0: no posedge
    #1 if (d.wakes != 1) $fatal(1, "index-induced negedge woke posedge waiter");
    bus.csb[0] = 1;
    #1 if (d.wakes != 2) $fatal(1, "reselected bit posedge missed");
    $display("PASS dynamic index"); $finish;
  end
endmodule
