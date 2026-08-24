// IEEE 1800-2017 15.3/15.4: the normal (non-killed) wake paths for every
// blocking mailbox and semaphore operation.
//
// The cancellable resource-wait mechanism inserts a "claim" step ahead of
// each wake's side effects. This test is the control for the kill-path
// regressions: it pins that an ordinary waiter still resumes EXACTLY once
// and that FIFO ordering and key accounting are unchanged.
module sv_resource_wait_normal_wake;

  mailbox #(int) mbx;
  mailbox #(int) bmbx;
  semaphore      sem;

  localparam int FINISHED = 0, RUNNING = 1, WAITING = 2, SUSPENDED = 3, KILLED = 4;

  process susp_p;

  int errors = 0;
  int peek_count = 0, get_count = 0, put_count = 0, sem_count = 0;
  int pk, g1, g2, t;

  task automatic chk(string what, int actual, int wanted);
    if (actual !== wanted) begin
      $display("FAILED %0s: got %0d exp %0d", what, actual, wanted);
      errors++;
    end
  endtask

  initial begin
    mbx  = new();
    bmbx = new(1);
    sem  = new(0);

    // ---- blocking peek, then two blocking gets: FIFO preserved ----
    fork
      begin
        mbx.peek(pk); peek_count++;
        mbx.get(g1);  get_count++;
        mbx.get(g2);  get_count++;
      end
    join_none
    #1;                            // the reader parks inside peek()

    mbx.put(11);
    #1;
    chk("peek woke once", peek_count, 1);
    chk("peek saw the head", pk, 11);
    chk("first get took the head", get_count, 1);
    chk("first get value", g1, 11);

    mbx.put(22);
    #1;
    chk("second get woke once", get_count, 2);
    chk("FIFO order preserved", g2, 22);
    chk("mailbox drained", mbx.num(), 0);

    // ---- blocking put on a bounded mailbox ----
    bmbx.put(1);                   // now full
    fork
      begin
        bmbx.put(2);  put_count++;
      end
    join_none
    #1;                            // the putter parks: no space
    chk("bounded put is still parked", put_count, 0);

    bmbx.get(t);                   // frees space; the parked put inserts
    chk("bounded get took the first item", t, 1);
    #1;
    chk("bounded put woke once", put_count, 1);
    chk("stored item was inserted", bmbx.num(), 1);
    bmbx.get(t);
    chk("stored item value", t, 2);
    chk("bounded mailbox drained", bmbx.num(), 0);

    // ---- blocking semaphore get for two keys ----
    fork
      begin
        sem.get(2);   sem_count++;
      end
    join_none
    #1;
    chk("semaphore waiter is parked", sem_count, 0);

    sem.put(1);
    #1;
    chk("one key is not enough", sem_count, 0);

    sem.put(1);
    #1;
    chk("semaphore waiter woke once", sem_count, 1);
    if (sem.try_get(1)) begin
      $display("FAILED: semaphore still had a key after the waiter took two");
      errors++;
    end

    // ---- suspend/resume across a resource wait (IEEE 1800-2017 9.7.2) ----
    // A suspended process is a separate condition from a resource wait, so
    // `suspended' is deliberately NOT folded into the blocked-on-wait
    // predicate. This pins the interaction: a wake that arrives while the
    // waiter is suspended must not run it, and resume() must then deliver it
    // exactly once rather than re-registering or double-scheduling.
    begin
      automatic int susp_runs = 0;
      automatic int susp_v = 0;
      mbx.put(0);                  // drain check below wants a known state
      void'(mbx.try_get(t));
      fork
        begin
          susp_p = process::self();
          mbx.get(susp_v);
          susp_runs++;
        end
      join_none
      #1;
      chk("resource-blocked process reports WAITING", susp_p.status(), WAITING);
      susp_p.suspend();
      chk("suspended process reports SUSPENDED", susp_p.status(), SUSPENDED);

      mbx.put(31);                 // wake arrives while the waiter is suspended
      #1;
      chk("suspended waiter did not run", susp_runs, 0);

      susp_p.resume();
      #1;
      chk("resumed waiter ran exactly once", susp_runs, 1);
      chk("resumed waiter got its message", susp_v, 31);
      chk("mailbox drained after resume", mbx.num(), 0);
      chk("resumed waiter finished", susp_p.status(), FINISHED);
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
