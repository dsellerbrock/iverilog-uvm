// IEEE 1800-2017 9.7.2: process::suspend() and process::resume(), plus the
// process::status() SUSPENDED transition. Before this fix suspend()/resume()
// were unimplemented (unknown method) and status() never returned SUSPENDED.
//
// Checks, all self-verifying (prints a bare PASSED on success):
//  1. suspend() freezes a running worker (a periodic counter stops advancing)
//     and status() reports SUSPENDED (=3).
//  2. resume() lets it continue (counter advances again).
//  3. An event delivered to a worker WHILE it is suspended is deferred: the
//     worker does not wake until resume(), then it runs.
//  4. kill() after resume reports KILLED (=4); status() of a finished worker
//     reports FINISHED (=0).
//  5. resume() of a non-suspended process and a second suspend() of an
//     already-suspended process are harmless.

module sv_process_suspend_resume;

  // process::status() enum values (IEEE 1800-2017 Table 9-1).
  localparam int FINISHED = 0, RUNNING = 1, WAITING = 2, SUSPENDED = 3, KILLED = 4;

  int errors = 0;

  task automatic expect_eq(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %0d exp %0d", what, got, exp);
      errors++;
    end
  endtask

  // --- Part 1/2: suspend freezes a counter, resume unfreezes it ---
  int counter = 0;
  process ticker;

  // --- Part 3: event delivered while suspended is deferred ---
  process waiter;
  event ev;
  int woke = 0;

  initial begin
    fork
      begin ticker = process::self(); forever begin #1; counter++; end end
    join_none
    fork
      begin waiter = process::self(); @ev; woke = 1; end
    join_none

    #5;                                    // ticker has counted ~5 times
    ticker.suspend();
    expect_eq("ticker suspended status", ticker.status(), SUSPENDED);
    begin
      automatic int frozen = counter;
      #10;                                 // while suspended the counter is frozen
      expect_eq("counter frozen", counter, frozen);
      ticker.suspend();                    // idempotent: second suspend is a no-op
      expect_eq("re-suspend status", ticker.status(), SUSPENDED);
      ticker.resume();
      #5;                                  // resumed: counter advances again
      if (counter <= frozen) begin
        $display("FAIL: counter did not advance after resume (%0d)", counter);
        errors++;
      end
    end

    // Event fires while the waiter is suspended -> deferred until resume.
    waiter.suspend();
    expect_eq("waiter suspended status", waiter.status(), SUSPENDED);
    ->ev;                                  // delivered while suspended
    #1;
    expect_eq("woke deferred while suspended", woke, 0);
    expect_eq("waiter still suspended", waiter.status(), SUSPENDED);
    waiter.resume();                       // deferred wake now fires
    #1;
    expect_eq("woke after resume", woke, 1);
    expect_eq("waiter finished", waiter.status(), FINISHED);

    // resume() of a process that is not suspended is a no-op.
    waiter.resume();

    // Kill the ticker and confirm the KILLED transition.
    ticker.kill();
    expect_eq("ticker killed status", ticker.status(), KILLED);

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
