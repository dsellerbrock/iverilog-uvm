// M6 item 5 parity gate: function-call atomicity under concurrency
// (IEEE 1800-2017 13.4.3 — a function executes as part of the calling
// process; it does not advance time and must not yield the active
// region to sibling processes).
//
// This pins the invariant the scheduled-call protocol MUST preserve.
// The synchronous model (default) satisfies it.  The naive scheduled
// design (IVL_SCHED_CALLF, migration step 2/3) VIOLATES it — suspending
// the caller across the call lets a concurrent process observe
// intermediate state and lets two concurrent calls of the same static
// function cross-contaminate.  Reduced from the ivtest reproducers
// pr2001162 and pr2053944.  See docs/conformance/m6_scheduled_call_protocol.md.
module m6_call_atomicity_test;
  int errors = 0;

  // (a) two concurrent processes each call the same STATIC function on
  //     the same event; each must get its own distinct return value.
  //     A static function has one shared return storage, so an
  //     interleaving of the two calls (which the naive scheduled path
  //     causes by suspending the caller) cross-contaminates the result.
  function int copy_val(int v); copy_val = v; endfunction   // static
  int v1, v2;
  event start_e;
  always @start_e v1 = copy_val(1);
  always @start_e v2 = copy_val(2);

  // (b) a shared counter incremented through a function must advance
  //     atomically per process: the read-modify-write of one process
  //     completes before the other observes the counter.
  int counter;
  function automatic int add1(int c); return c + 1; endfunction
  int seen_a, seen_b;

  initial begin
    // (a)
    ->start_e;
    #1;
    if (v1 !== 1) begin $display("FAIL atomicity-a v1=%0d exp 1", v1); errors++; end
    if (v2 !== 2) begin $display("FAIL atomicity-a v2=%0d exp 2", v2); errors++; end

    // (b) sequential calls in one process compose without loss
    counter = 0;
    counter = add1(counter);
    counter = add1(counter);
    counter = add1(counter);
    if (counter !== 3) begin $display("FAIL atomicity-b counter=%0d exp 3", counter); errors++; end

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
