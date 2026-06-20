// Regression: wait(!this.cfg.member) on a scalar class member must wake when
// the member is written through a DIFFERENT handle to the same object.
//
// A wait whose condition reads a scalar property through a class-MEMBER handle
// (this.cfg.in_reset) elaborates its anyedge onto the outermost handle's net
// (the this/@ net), and the cfg object is fetched via %prop/obj.  A cross-handle
// write to cfg.in_reset (e.g. tl_monitor writing the cfg that tl_host_driver
// waits on -- both share one cfg via the UVM agent) did not fire that anyedge,
// so the wait only woke incidentally on a later unrelated event.  In OpenTitan
// UART DV this let a TL request slip into pending_a_req during the wake gap and
// raised "Check failed pending_a_req.size() == 0".
//
// %prop/obj now registers the loaded property object as an edge-only alias of
// the waitable root net (same mechanism as the assoc-element case), so the
// cross-handle store wakes the wait in the same timestep.

module top;

  class cfg_c;
    bit in_reset = 1;
  endclass

  // writer: clears cfg.in_reset through its own handle, at t=20
  class writer_c;
    cfg_c cfg;
    task automatic run();
      #20;
      cfg.in_reset = 0;
    endtask
  endclass

  // waiter: waits on the SAME cfg object via its member handle
  class waiter_c;
    cfg_c cfg;
    bit   woke = 0;
    time  woke_t = 0;
    task automatic run();
      wait(!cfg.in_reset);          // this.cfg.in_reset, scalar member chain
      woke   = 1;
      woke_t = $time;
    endtask
  endclass

  initial begin
    cfg_c   cfg;
    writer_c wr;
    waiter_c wt;

    cfg = new();
    wr = new(); wr.cfg = cfg;        // same object to both (like a UVM agent cfg)
    wt = new(); wt.cfg = cfg;

    fork wr.run(); wt.run(); join_none

    #100;
    if (wt.woke && wt.woke_t == 20)
      $display("PASS");
    else
      $display("wait_member_cross_handle_test FAILED: woke=%0d woke_t=%0t (expected woke @20)",
               wt.woke, wt.woke_t);
    $finish;
  end
endmodule
