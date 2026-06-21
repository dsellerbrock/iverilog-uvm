// Regression: an event control on a clocking block accessed through a
// virtual-interface MODPORT (`@(vif.modport.clocking_block)`) must wait on the
// clocking block's event, exactly like the direct form (`@(vif.cb)`).
//
// iverilog's clocking-event resolver only recognized the direct form; the
// modport-qualified form failed to resolve ("Failed to evaluate event
// expression ... event skipped"), so @() did NOT block and fell through
// immediately. This is the OpenTitan uart_monitor bug: `@(cfg.vif.mon_tx_mp.
// mon_tx_cb)` (negedge uart_tx_clk, with input skew) sampled the TX line 11
// times in zero time -> every frame read as all-zeros -> "No stop bit".
//
// Faithful to uart_if: internal-variable clock, negedge clocking event, input
// skew, accessed via a modport through a virtual interface.

interface uif();
  bit   clk = 1'b1;
  logic sig;
  clocking mon_cb @(negedge clk);
    input #2 sig;
  endclocking
  modport mon_mp(clocking mon_cb);
endinterface

class mon;
  virtual uif vif;
  int blocked_count = 0;
  // mirror collect: wait on the modport clocking event N times, each must
  // advance time (block) and land on a negedge.
  task automatic collect(int n);
    realtime t0;
    for (int i = 0; i < n; i++) begin
      t0 = $realtime;
      @(vif.mon_mp.mon_cb);
      if ($realtime > t0) blocked_count++;
    end
  endtask
endclass

module top;
  uif intf();
  mon m;
  int errors = 0;
  // toggle the internal clock (one negedge per 10ns)
  always #5 intf.clk = ~intf.clk;
  initial begin
    intf.sig = 0;
    m = new(); m.vif = intf;
    m.collect(5);
    if (m.blocked_count != 5) begin
      $display("FAIL: modport clocking @() blocked %0d/5 times", m.blocked_count);
      errors++;
    end
    if (errors == 0) $display("PASS");
    else $display("clocking_modport_event_wait_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
