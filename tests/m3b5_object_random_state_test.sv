// M3B-5: per-object random state (IEEE 1800-2017 18.13).
//
// srandom() and set_randstate() elaborated to an empty block and
// get_randstate() returned a literal empty string, so seeding an object
// silently did nothing: re-seeding one object with the same value gave
// different results, two objects seeded identically diverged, and no
// seeded flow was reproducible. All three now drive the object's own
// generator (vvp_cobject::rng_*).
//
// The generator is active only once the object has been SEEDED --
// explicitly, via srandom() or set_randstate(). An object that was never
// seeded keeps drawing from the global generator, so unseeded
// randomization sequences are unchanged. Seeding is what opts an object
// in; see the M3B-5 ROADMAP row.
//
// process::srandom()/get_randstate()/set_randstate() drive the per-THREAD
// generator (18.13.2), which is separate from any object's. $urandom uses
// it when there is no seeded enclosing object, so an object's seed takes
// precedence inside that object's own methods. UVM relies on the
// save/restore idiom (uvm_report_message.svh, uvm_resource_pool.svh,
// uvm_component.svh), so it has to work rather than be diagnosed away.
//
// NOTE on `process p = process::self();' -- a declaration initializer with
// no explicit lifetime is hoisted to a separate initialization thread, so
// it captures the WRONG process. Icarus already warns about that form
// ("Static variable initialization requires explicit lifetime in this
// context"); write `automatic process p = process::self();' or assign
// inside the block, as below.
module m3b5_object_random_state_test;

  class C;
    rand bit [7:0] v;
    rand int       w;
    // Unqualified forms inside a method are this.srandom() /
    // this.get_randstate().
    function void seed_me(int s);   srandom(s);            endfunction
    function string my_state();     return get_randstate(); endfunction
    function int    draw_urandom(); return $urandom();      endfunction
  endclass

  // A constrained property goes through the solver rather than the raw
  // random fill, so it needs its own check.
  class D;
    rand bit [7:0] x;
    constraint c { x inside {[10:200]}; }
  endclass

  int errors = 0;

  task automatic check(bit cond, string what);
    if (!cond) begin
      $display("FAIL %s", what);
      errors++;
    end
  endtask

  initial begin
    automatic C a = new, b = new;
    automatic D d = new;
    automatic string st;
    int r1[4], r2[4];
    int u1, u2;

    // 1. Two objects seeded the same produce the same value.
    a.srandom(42);
    b.srandom(42);
    void'(a.randomize());
    void'(b.randomize());
    check(a.v === b.v, "two objects with the same seed differ");

    // 2. Re-seeding one object repeats its whole stream, not just one draw.
    a.srandom(7);
    for (int i = 0; i < 4; i++) begin void'(a.randomize()); r1[i] = a.v; end
    a.srandom(7);
    for (int i = 0; i < 4; i++) begin void'(a.randomize()); r2[i] = a.v; end
    for (int i = 0; i < 4; i++)
      check(r1[i] === r2[i], $sformatf("re-seeded stream differs at draw %0d", i));

    // 3. srandom(0) is a legal seed and must be reproducible too -- 0 is
    //    the one state this generator cannot use directly.
    a.srandom(0); void'(a.randomize()); r1[0] = a.v;
    a.srandom(0); void'(a.randomize());
    check(a.v === r1[0], "srandom(0) is not reproducible");

    // 4. get_randstate()/set_randstate() round-trip the exact stream,
    //    across more than one property.
    a.srandom(11);
    st = a.get_randstate();
    check(st.len() > 0, "get_randstate() returned an empty string");
    void'(a.randomize()); r1[0] = a.v; r1[1] = a.w;
    a.set_randstate(st);
    void'(a.randomize());
    check(a.v === r1[0] && a.w === r1[1],
          "set_randstate() did not restore the stream");

    // 5. The unqualified in-method forms reach the same object state.
    a.seed_me(5); void'(a.randomize()); r1[0] = a.v;
    a.seed_me(5); void'(a.randomize());
    check(a.v === r1[0], "unqualified srandom() is not reproducible");
    check(a.my_state().len() > 0, "unqualified get_randstate() is empty");

    // 6. 18.13.1: $urandom inside a method follows the object's seed.
    a.srandom(9); u1 = a.draw_urandom();
    a.srandom(9); u2 = a.draw_urandom();
    check(u1 == u2, "$urandom inside a method ignores the object seed");

    // 7. A CONSTRAINED property is both reproducible and still legal.
    d.srandom(4);
    for (int i = 0; i < 6; i++) begin void'(d.randomize()); r1[0] = d.x;
      check(d.x >= 10 && d.x <= 200, "constrained randomize left its range");
    end
    d.srandom(4);
    for (int i = 0; i < 6; i++) begin
      void'(d.randomize());
      r2[0] = d.x;
    end
    d.srandom(4);
    void'(d.randomize()); r1[1] = d.x;
    d.srandom(4);
    void'(d.randomize());
    check(d.x === r1[1], "constrained randomize is not seed-reproducible");

    // 8. 18.13.2: the PROCESS generator, and UVM's save/restore idiom.
    begin
      automatic process p = process::self();
      automatic string pst;
      int p1, p2;
      p.srandom(21); p1 = $urandom();
      p.srandom(21); p2 = $urandom();
      check(p1 == p2, "process srandom() is not reproducible");

      p.srandom(3);
      pst = p.get_randstate();
      check(pst.len() > 0, "process get_randstate() is empty");
      p1 = $urandom();
      p.set_randstate(pst);
      p2 = $urandom();
      check(p1 == p2, "process set_randstate() did not restore the stream");
    end

    // 9. An object's seed wins over the process seed inside its methods.
    begin
      automatic process p = process::self();
      int o1, o2;
      p.srandom(77);
      a.srandom(31); o1 = a.draw_urandom();
      p.srandom(99);            // perturbing the PROCESS must not matter
      a.srandom(31); o2 = a.draw_urandom();
      check(o1 == o2, "object seed did not take precedence over process seed");
    end

    if (errors == 0) $display("PASS m3b5_object_random_state_test");
    $finish(0);
  end
endmodule
