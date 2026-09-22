interface selected_suppression_if;
  logic [3:0] csb;
endinterface
class selected_suppression_cfg;
  virtual selected_suppression_if vif;
endclass
class selected_suppression_dev;
  selected_suppression_cfg cfg;
  int active_csb;
  int wakes;
  task automatic wait_pos;
    @(posedge cfg.vif.csb[active_csb]);
    wakes++;
  endtask
endclass
module selected_suppression;
  selected_suppression_if bus();
  selected_suppression_dev d;
  initial begin
    bus.csb = 4'b0000;
    d = new; d.cfg = new; d.cfg.vif = bus; d.active_csb = 2;
    fork d.wait_pos(); join_none
    #1 bus.csb[1] = 1'b1;
    #1 if (d.wakes != 0) $fatal(1, "nonselected bit woke live waiter");
    bus.csb[2] = 1'b1;
    #1 if (d.wakes != 1) $fatal(1, "selected posedge missed");
    bus.csb[2] = 1'b1;
    #1 if (d.wakes != 1) $fatal(1, "equal selected assignment woke twice");
    $display("PASS selected suppression"); $finish;
  end
endmodule
