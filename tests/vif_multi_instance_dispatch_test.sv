// Virtual-interface method dispatch must route to the instance the handle
// actually points at, at run time, AND stage the call arguments into that
// instance's context.  This guards the %fork/vif / of_FORK_VIF machinery that
// the deferred-interface-task path ("$ivl_iface_late_vif$...") relies on: a
// class holds a vif handle, the handle is reassigned between calls, and the
// SAME method call site must reach two different interface instances with the
// correct arguments each time.
//
// Before the arg-staging was wired through of_FORK_VIF, the call would either
// run a single statically-chosen instance (wrong one) or drop the arguments
// (e.g. a zero-width reset).  This is exactly the OpenTitan failure where
// cfg.clk_rst_vifs[ral_name].apply_reset() was applied to the wrong clk_rst_if
// so the fast clock never started.
module top;
  // Two distinct instances of the same interface.
  my_if if0();
  my_if if1();

  // A class that calls an interface task through a (re-assignable) vif handle.
  class driver;
    virtual my_if vif;
    task automatic drive(int a, int b = 7);
      vif.do_it(a, b);   // run-time-selected instance + staged args
    endtask
  endclass

  initial begin
    driver d = new();

    d.vif = if0;
    d.drive(123, 456);   // must reach if0 with (123, 456)

    d.vif = if1;
    d.drive(11);         // must reach if1 with (11, default 7)

    #1;
    if (if0.last_a === 123 && if0.last_b === 456 &&
        if1.last_a === 11  && if1.last_b === 7)
      $display("VIF_MULTI_INSTANCE_DISPATCH_PASS");
    else
      $display("VIF_MULTI_INSTANCE_DISPATCH_FAIL if0=(%0d,%0d) if1=(%0d,%0d)",
               if0.last_a, if0.last_b, if1.last_a, if1.last_b);
    $finish;
  end
endmodule

interface my_if;
  int last_a;
  int last_b;
  task automatic do_it(int a, int b = 7);
    last_a = a;
    last_b = b;
  endtask
endinterface
