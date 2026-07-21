// IEEE 1800-2017 9.7: process::status() must report the correct state.
// Previously a process parked on a procedural delay (#d) reported RUNNING
// instead of WAITING, because a delay reschedules the thread on the timing
// wheel (leaving is_scheduled set) with no distinguishing flag. An
// i_am_delaying flag now drives the WAITING transition for delay-parked
// processes; RUNNING, event-WAITING, FINISHED, SUSPENDED and KILLED are
// also checked.
module sv_process_status_transitions;
  localparam int FINISHED=0, RUNNING=1, WAITING=2, SUSPENDED=3, KILLED=4;
  int errors = 0;
  task automatic chk(string what, int got, int exp);
    if (got !== exp) begin $display("FAIL %0s: got %0d exp %0d", what, got, exp); errors++; end
  endtask

  process p_delay, p_event, p_done, p_susp, p_kill, self_p;
  event ev;

  initial begin
    // RUNNING: a process querying its own status while executing.
    self_p = process::self();
    chk("self running", self_p.status(), RUNNING);

    fork begin p_delay = process::self(); #1000; end join_none
    fork begin p_event = process::self(); @ev;   end join_none
    fork begin p_done  = process::self();        end join_none  // finishes at once
    fork begin p_susp  = process::self(); #1000; end join_none
    fork begin p_kill  = process::self(); #1000; end join_none
    #1;  // let the workers start and park

    chk("delay parked -> WAITING", p_delay.status(), WAITING);
    chk("event parked -> WAITING", p_event.status(), WAITING);
    chk("ran to end   -> FINISHED", p_done.status(), FINISHED);

    p_susp.suspend();
    chk("suspended -> SUSPENDED", p_susp.status(), SUSPENDED);
    p_susp.resume();
    chk("resumed -> WAITING (back on its delay)", p_susp.status(), WAITING);

    p_kill.kill();
    chk("killed -> KILLED", p_kill.status(), KILLED);

    ->ev; #1;
    chk("event fired -> FINISHED", p_event.status(), FINISHED);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
