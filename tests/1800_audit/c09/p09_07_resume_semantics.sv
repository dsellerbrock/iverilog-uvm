module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  process pd, pw, pe;
  int flag, tdone, wdone, edone; time t_res; event ev;
  initial begin
    fork begin pd = process::self(); #5 tdone = $time; end join_none
    wait (pd != null); #1 pd.suspend();
    #10 t_res = $time; pd.resume(); #1;
    chk("9.7.resume_after_delay_expired_continues_now", tdone == t_res);
    fork begin pw = process::self(); wait (flag); wdone = 1; end join_none
    wait (pw != null); #1 pw.suspend();
    #1 flag = 1; #1 chk("9.7.suspended_waiter_not_woken_by_condition", wdone == 0);
    pw.resume(); #1 chk("9.7.resume_after_condition_true_continues", wdone == 1);
    fork begin pe = process::self(); @ev; edone = 1; end join_none
    wait (pe != null); #1 pe.suspend();
    #1 ->ev; #1 $display("INFO event_while_suspended edone=%0d status=%s", edone, pe.status().name());
    pe.resume(); #1 $display("INFO after_resume edone=%0d status=%s", edone, pe.status().name());
    chk("9.7.resume_does_not_replay_event", edone == 0);
    ->ev; #1 chk("9.7.resumed_waiter_wakes_on_next_event", edone == 1);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
