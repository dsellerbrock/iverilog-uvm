interface concurrent_same_signal_delivery_if;
  logic [1:0] csb;
endinterface

class concurrent_same_signal_delivery_cfg;
  virtual concurrent_same_signal_delivery_if vif;
endclass

class concurrent_same_signal_delivery_dev;
  concurrent_same_signal_delivery_cfg cfg;
  int index;
  int wakes;
  task automatic wait_two_posedges;
    repeat (2) begin
      @(posedge cfg.vif.csb[index]);
      wakes++;
    end
  endtask
endclass

module concurrent_same_signal_delivery;
  concurrent_same_signal_delivery_if bus();
  concurrent_same_signal_delivery_dev first, second;
  initial begin
    bus.csb = 2'b00;
    first = new; first.cfg = new; first.cfg.vif = bus; first.index = 1;
    second = new; second.cfg = new; second.cfg.vif = bus; second.index = 1;

    fork: first_wait first.wait_two_posedges(); join_none
    fork: second_wait second.wait_two_posedges(); join_none
    fork: timeout_guard begin
      #30 $fatal(1, "concurrent same-signal delivery test timed out");
    end join_none

    #1 bus.csb[0] = 1'b1;
    #1 bus.csb[0] = 1'b0;
    #1 if (first.wakes != 0 || second.wakes != 0)
      $fatal(1, "nonselected transition woke a live waiter");
    bus.csb[1] = 1'b1;
    #1 if (first.wakes != 1 || second.wakes != 1)
      $fatal(1, "first selected edge did not wake both waiters");

    bus.csb[1] = 1'b0;
    #1 bus.csb[0] = 1'b1;
    #1 bus.csb[0] = 1'b0;
    #1 if (first.wakes != 1 || second.wakes != 1)
      $fatal(1, "later nonselected transition woke a re-armed waiter");
    bus.csb[1] = 1'b1;
    #1 if (first.wakes != 2 || second.wakes != 2)
      $fatal(1, "second selected edge did not wake both re-armed waiters");
    $display("PASS concurrent same-signal delivery");
    $finish;
  end
endmodule
