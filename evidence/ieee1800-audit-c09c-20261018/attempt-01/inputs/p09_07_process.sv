module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  process p0, pn, p1, p2, p3, pf, p4, p5, p6;
  int cnt1, cnt2, desc_ran, fd, sc, sc0, got, s6; time t0; event ev;
  task automatic selfsusp(); process me; me = process::self(); me.suspend(); endtask
  initial begin : main
    chk("9.7.default_null", pn == null);
    p0 = process::self();
    chk("9.7.self_nonnull_and_stable", p0 != null && p0 == process::self());
    chk("9.7.self_status_running", p0.status() == process::RUNNING);
    t0 = $time;
    fork begin p1 = process::self(); #5 cnt1 = 1; end join_none
    wait (p1 != null);
    chk("9.7.status_waiting_in_delay", p1.status() == process::WAITING);
    p1.await();
    chk("9.7.await_blocks_until_finished", cnt1 == 1 && ($time - t0) == 5 && p1.status() == process::FINISHED);
    fork begin p2 = process::self(); #10 cnt2 = 1; end join_none
    wait (p2 != null);
    chk("9.7.distinct_handles", p1 != p2);
    p2.kill();
    $display("INFO 9.7.kill_immediate_status=%s (2023: terminated before kill returns)", p2.status().name());
    #0 chk("9.7.kill_status_killed", p2.status() == process::KILLED);
    #20 chk("9.7.kill_stops_process", cnt2 == 0);
    p2.await(); chk("9.7.await_on_killed_returns", 1);
    fork begin p3 = process::self(); fork #10 desc_ran = 1; join_none #50; end join_none
    wait (p3 != null); #1 p3.kill();
    #20 chk("9.7.kill_kills_descendants", desc_ran == 0);
    fork begin pf = process::self(); fork #10 fd = 1; join_none end join_none
    wait (pf != null); #1;
    chk("9.7.status_finished_after_exit", pf.status() == process::FINISHED);
    pf.kill();
    #20 $display("INFO 9.7.kill_finished_parent_descendant_ran=%0d (2023 requires 0; 2017 unspecified)", fd);
    fork begin p4 = process::self(); forever #1 sc++; end join_none
    wait (p4 != null); #3 p4.suspend();
    $display("INFO 9.7.suspend_immediate_status=%s (2023: suspended before suspend returns)", p4.status().name());
    #1 sc0 = sc;
    chk("9.7.suspend_status", p4.status() == process::SUSPENDED);
    #5 chk("9.7.suspend_halts_progress", sc == sc0);
    p4.suspend(); chk("9.7.suspend_twice_no_effect", 1);
    p4.resume(); #5 chk("9.7.resume_restarts", sc > sc0);
    p4.resume(); chk("9.7.resume_on_non_suspended_noop", p4.status() != process::SUSPENDED);
    p4.kill();
    fork begin p5 = process::self(); @ev; got++; end join_none
    wait (p5 != null); #1 p5.suspend();
    #1 ->ev; #1 chk("9.7.suspended_waiter_misses_event", got == 0);
    p5.resume(); #1 chk("9.7.resumed_waiter_still_waiting", got == 0 && p5.status() != process::FINISHED);
    ->ev; #1 chk("9.7.resumed_waiter_wakes_on_next_event", got == 1);
    fork begin p6 = process::self(); selfsusp(); s6 = 1; end join_none
    wait (p6 != null); #1;
    chk("9.7.self_suspend_in_task_stops", s6 == 0 && p6.status() == process::SUSPENDED);
    p6.resume(); #1 chk("9.7.resume_after_self_suspend_continues", s6 == 1);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
