// R3 (IEEE 1800-2017 18.13.1): RANDOM STABILITY -- hierarchical RNG
// seeding, self-checking regression.
//
// Before this fix, an unseeded thread/object drew from a single shared
// global generator, so an unrelated $urandom/randomize() call ANYWHERE
// in the design could perturb every other unseeded sequence. Now every
// thread and every class object is seeded AT CREATION from the next
// value of its creator's own generator (a real fork...join/join_any/
// join_none branch from its parent thread's logical-process generator;
// a class object, at `new', from the constructing thread's logical-
// process generator), forming a tree rooted at the design itself. See
// the R3 block comment above thread_rng_srandom_()/
// logical_process_thread_() in vvp/vthread.cc for the exact derivation.
//
// NOTE ON TEST METHOD: within a single simulation run, calling the same
// code twice from the SAME persistent thread naturally advances that
// thread's RNG further each time (exactly like calling $urandom() twice
// in a row) -- that is correct hierarchical behaviour, not a bug, and is
// NOT what "stability" means. To test reproducibility/stability
// meaningfully within one run, this file resets the CALLING thread's own
// generator with process::self().srandom(<fixed>) immediately before
// each comparable measurement, so what differs between two measurements
// is only whatever happened in some OTHER thread in between -- exactly
// the case 18.13.1 says must NOT matter.
//
// This test pins the four load-bearing properties of the hierarchy:
//
//   1. Two objects constructed in sequence by the SAME thread draw
//      DIFFERENT, independently-evolving seeds/sequences.
//   2. Random STABILITY: from a fixed thread-RNG state, inserting an
//      unrelated object/thread -- created by a DIFFERENT thread in
//      between -- does not change this thread's own next two objects'
//      sequence one bit.
//   3. A fork's two children draw independent sequences, and (from a
//      fixed parent-RNG state) that pair of sequences is exactly
//      reproducible.
//   4. srandom(<fixed seed>) on an object still yields the exact
//      documented sequence (18.13.3 untouched): reseeding to the same
//      value after any amount of unrelated hierarchy activity
//      reproduces the same draws.
module r3_random_stability_test;

  class C;
    rand int v;
  endclass

  int errors = 0;
  task automatic check(bit cond, string what);
    if (!cond) begin
      $display("FAIL %s", what);
      errors++;
    end
  endtask

  task automatic make_ab(output int av, output int bv);
    automatic C a = new;
    automatic C b = new;
    void'(a.randomize());
    void'(b.randomize());
    av = a.v;
    bv = b.v;
  endtask

  // A SEPARATE root/static thread (its own top-level `initial' block, so
  // its own independent creator lineage -- NOT a fork/task call spawned
  // from the main thread below, which would just be a sibling under the
  // SAME parent and would legitimately advance that parent's sequence).
  // Handshakes with the main thread via a pair of named events so it
  // runs exactly once, on cue, between two measurements there.
  event ev_go, ev_done;
  initial begin
    forever begin
      automatic C noise;
      @(ev_go);
      noise = new;
      void'(noise.randomize());
      ->ev_done;
    end
  end

  task automatic unrelated_noise();
    ->ev_go;
    @(ev_done);
  endtask

  initial begin
    automatic process self_p = process::self();
    int a_val, b_val, a_val2, b_val2;

    // ------------------------------------------------------------------
    // 1. Two objects made back to back by the same thread differ.
    // ------------------------------------------------------------------
    self_p.srandom(100);
    make_ab(a_val, b_val);
    check(a_val !== b_val, {"two objects made back to back by the same ",
                            "thread got the SAME derived seed/sequence"});

    // ------------------------------------------------------------------
    // 2. Random STABILITY: reset this thread's RNG, measure a/b; reset
    //    it again to the SAME seed, let a completely different thread
    //    do unrelated work, then measure a/b again. Must be identical.
    // ------------------------------------------------------------------
    self_p.srandom(200);
    make_ab(a_val, b_val);

    self_p.srandom(200);
    unrelated_noise();        // different thread; must not perturb below
    make_ab(a_val2, b_val2);
    check(a_val === a_val2 && b_val === b_val2,
          {"an unrelated object built by a DIFFERENT thread changed this ",
           "thread's own a/b sequence -- random stability violated"});

    // ------------------------------------------------------------------
    // 3. A fork's two children draw independent sequences, and that
    //    pair is exactly reproducible from a fixed parent-RNG state.
    // ------------------------------------------------------------------
    begin
      int c1, c2, d1, d2;

      self_p.srandom(300);
      fork
        begin automatic C x = new; void'(x.randomize()); c1 = x.v; end
        begin automatic C y = new; void'(y.randomize()); c2 = y.v; end
      join
      check(c1 !== c2, "a fork's two children drew the SAME sequence");

      // Reset the PARENT thread's RNG to the same state and fork an
      // identical pair again: same parent state + same topology must
      // give the same two derived child seeds.
      self_p.srandom(300);
      fork
        begin automatic C x = new; void'(x.randomize()); d1 = x.v; end
        begin automatic C y = new; void'(y.randomize()); d2 = y.v; end
      join
      check(c1 === d1 && c2 === d2,
            {"resetting the parent thread's RNG and re-forking the same ",
             "topology produced different children -- hierarchical ",
             "seeding is not deterministic"});
    end

    // ------------------------------------------------------------------
    // 4. srandom(<fixed seed>) on an OBJECT is untouched by any amount
    //    of unrelated hierarchy activity in between (18.13.3).
    // ------------------------------------------------------------------
    begin
      automatic C s1 = new;
      automatic C s2 = new;
      int first, second;

      s1.srandom(1234);
      void'(s1.randomize());
      first = s1.v;

      // Pile on unrelated hierarchy activity: more objects, a fork.
      unrelated_noise();
      make_ab(a_val2, b_val2);
      fork
        begin automatic C z = new; void'(z.randomize()); end
      join

      s2.srandom(1234);
      void'(s2.randomize());
      second = s2.v;

      check(first === second,
            {"srandom(1234) gave a different result after unrelated ",
             "hierarchy activity -- 18.13.3 explicit reseed regressed"});
    end

    if (errors == 0) $display("PASS r3_random_stability_test");
    $finish(0);
  end
endmodule
