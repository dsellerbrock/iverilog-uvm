interface concurrent_same_signal_cancel_if;
  logic [1:0] csb;
endinterface

class concurrent_same_signal_cancel_cfg;
  virtual concurrent_same_signal_cancel_if vif;
endclass

class concurrent_same_signal_cancel_dev;
  concurrent_same_signal_cancel_cfg cfg;
  int index;
  int wakes;
  task automatic wait_pos;
    @(posedge cfg.vif.csb[index]);
    wakes++;
  endtask
endclass

module concurrent_same_signal_cancel;
  concurrent_same_signal_cancel_if bus();
  concurrent_same_signal_cancel_dev cancelled, survivor;
  initial begin
    bus.csb = 2'b00;
    cancelled = new; cancelled.cfg = new; cancelled.cfg.vif = bus; cancelled.index = 1;
    survivor = new; survivor.cfg = new; survivor.cfg.vif = bus; survivor.index = 1;

    fork: cancelled_wait cancelled.wait_pos(); join_none
    fork: survivor_wait survivor.wait_pos(); join_none
    fork: timeout_guard begin
      #20 $fatal(1, "concurrent same-signal edge test timed out");
    end join_none

    #1 disable cancelled_wait;
    bus.csb[0] = 1'b1;
    #1 bus.csb[0] = 1'b0;
    #1 if (cancelled.wakes != 0 || survivor.wakes != 0)
      $fatal(1, "nonselected transition woke a waiter");
    bus.csb[1] = 1'b1;
    #1 if (cancelled.wakes != 0 || survivor.wakes != 1)
      $fatal(1, "cancellation did not preserve surviving waiter");
    $display("PASS concurrent same-signal cancellation");
    $finish;
  end
endmodule
