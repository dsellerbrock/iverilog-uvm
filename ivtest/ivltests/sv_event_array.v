// Unpacked arrays of named events (IEEE 1800-2017 6.17, 15.5): each
// element is an independent named event, triggered with `->' and
// `->>', waited on with `@', and queried with `.triggered'.
//
// The declaration used to be a hard compile-time refusal:
//
//     sorry: event arrays are not supported.
//
// Named events were modeled as one compile-time NetEvent -- one
// vvp_net_t functor per declaration -- with no notion of N independent
// runtime events under one name, and no word-addressed storage for
// events the way nets and objects have. Elements are now backed by a
// design-global slot table, each slot lazily materializing its own
// dynamic named event (the same mechanism per-instance class events
// already used), with the declared (base, count) carried to the
// trigger/wait/test opcodes and the run-time index bounds-checked.
//
// `.triggered' on an element needed its own fix along the way: it
// compiled but always read false, because the query landed on the
// array's unused group event instead of the element.
//
// Multi-dimensional event arrays are a LOUD refusal, at the
// declaration and again at every use site.

module main;

  event e[3];
  event nb[2];
  int   fails = 0;

  int hit[3];
  int idx;
  int trig_seen = 0;
  int nb_seen = 0;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  // waiters on distinct elements
  initial begin @e[0] hit[0] = 1; end
  initial begin @e[1] hit[1] = 1; end
  initial begin @e[2] hit[2] = 1; end

  // a nonblocking trigger wakes a waiter in the same time step
  initial begin @nb[1] nb_seen = 1; end

  initial begin
    // ---- constant index ----
    #1 ->e[1];
    #1;
    chk("constant-index trigger woke its waiter", hit[1], 1);
    chk("element 0 was not disturbed",            hit[0], 0);
    chk("element 2 was not disturbed",            hit[2], 0);

    // ---- run-time index ----
    idx = 2;
    ->e[idx];
    #1;
    chk("run-time-index trigger woke its waiter", hit[2], 1);
    chk("element 0 still untouched",              hit[0], 0);

    // ---- .triggered on an element, same time step ----
    ->e[0];
    if (e[0].triggered) trig_seen = 1;
    #1;
    chk("element .triggered read true in its step", trig_seen, 1);
    chk("the trigger also woke the waiter",         hit[0],    1);

    // ---- nonblocking trigger ->> ----
    ->>nb[1];
    #1;
    chk("nonblocking element trigger woke waiter",  nb_seen,   1);

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
    $finish(0);
  end

endmodule
