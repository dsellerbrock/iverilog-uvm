// G68: process::status() must query the LIVE process state (IEEE
// 1800-2017 9.7), not a placeholder property slot.  Also checks the
// process state enum constants (FINISHED=0, RUNNING=1, WAITING=2,
// SUSPENDED=3, KILLED=4) and the UVM sequencer zombie-predicate shape
// that exposed the defect (find ... with (... && status inside
// {KILLED, FINISHED})).
class g68_req;
  int request;
  process process_id;
endclass

module g68_process_status_test;
  int errors = 0;
  process p_self, p_child, p_killed;
  g68_req rq;
  g68_req q[$];
  g68_req zombies[$];

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  initial begin
    // enum constants per 9.7
    check("FINISHED", process::FINISHED, 0);
    check("RUNNING", process::RUNNING, 1);
    check("WAITING", process::WAITING, 2);
    check("SUSPENDED", process::SUSPENDED, 3);
    check("KILLED", process::KILLED, 4);

    // the running process observes itself RUNNING
    p_self = process::self();
    check("self RUNNING", p_self.status(), process::RUNNING);

    // a live forked child is not FINISHED/KILLED
    fork begin
      p_child = process::self();
      #10;
    end join_none
    #1;
    if (p_child.status() inside {process::KILLED, process::FINISHED}) begin
      $display("FAIL live child reads dead (status=%0d)", p_child.status());
      errors++;
    end

    // a killed child reads KILLED
    fork begin
      p_killed = process::self();
      #100;
    end join_none
    #1;
    p_killed.kill();
    check("killed child", p_killed.status(), process::KILLED);

    // a completed child reads FINISHED
    #20;
    check("finished child", p_child.status(), process::FINISHED);

    // the UVM sequencer zombie-predicate shape: a live lock request
    // must NOT match (this deadlocked seq_trace_test/vif_smoke when
    // status was a dead property and inside bound looser than &&)
    rq = new;
    rq.request = 1;
    rq.process_id = p_self;
    q.push_back(rq);
    zombies = q.find(item) with (item.request == 1
        && item.process_id.status inside {process::KILLED, process::FINISHED});
    check("live req not zombie", zombies.size(), 0);

    // ... and a dead one must match
    rq = new;
    rq.request = 1;
    rq.process_id = p_killed;
    q.push_back(rq);
    zombies = q.find(item) with (item.request == 1
        && item.process_id.status inside {process::KILLED, process::FINISHED});
    check("dead req is zombie", zombies.size(), 1);

    // a non-lock dead-process request must not match (the && guard)
    q.delete();
    rq = new;
    rq.request = 0;
    rq.process_id = p_killed;
    q.push_back(rq);
    zombies = q.find(item) with (item.request == 1
        && item.process_id.status inside {process::KILLED, process::FINISHED});
    check("non-lock not zombie", zombies.size(), 0);

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
