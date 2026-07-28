// M3B-11/12/13/14: WHICH variables does a randomize() call actually
// solve for, and which hooks run?
//
// Four IEEE clauses answer one question, and all four were wrong in the
// same direction -- randomize() solved for more than it was allowed to,
// silently:
//
//   18.3   a class property that is NOT declared `rand' is a STATE
//          variable: it takes part in constraints at the value it holds
//          when randomize() is called. Every constraint item that
//          mentioned one was DROPPED instead ("not representable in the
//          constraint solver"), so `constraint c { a == b; }' with a
//          non-rand `b' silently became no constraint at all and
//          randomize() returned 1 with a violated constraint.
//
//   18.8   rand_mode(0) freezes a variable. It skipped the random
//          pre-fill but the constraint solver still solved for the
//          variable and wrote the answer back, so a frozen field
//          changed anyway. rand_mode() called as a FUNCTION always
//          returned 0, so the standard save/restore idiom
//              bit save = obj.f.rand_mode(); ... obj.f.rand_mode(save);
//          always restored the field DISABLED.
//
//   18.11  randomize(a, b) randomizes only the listed variables; every
//          other property is a state variable for that call, and a
//          listed variable is random even if it was never declared
//          `rand'. randomize(null) randomizes NOTHING -- it only
//          reports whether the constraints are satisfiable -- and calls
//          neither pre_randomize nor post_randomize. The argument list
//          was ignored outright: randomize(b) randomized the whole
//          object and randomize(null) mutated it.
//
//   18.6.2 post_randomize() runs only when randomize() SUCCEEDED. It
//          was emitted unconditionally, so it ran after a failed solve
//          over the object's stale values. pre_randomize() runs either
//          way.
//
// One mechanism underlies all four: a randomize() call has a set of
// random variables, and everything else the object holds is pinned to
// its current value for the duration of the solve.

class Pair;
  rand bit [7:0] a;
  rand bit [7:0] b;
  constraint cb { b == a + 1; }
endclass

class WithState;
  rand bit [7:0] x;
  bit  [7:0]     lo;              // state variables (18.3)
  bit  [7:0]     hi;
  bit  [7:0]     tbl[4];
  bit  [7:0]     mask[4];
  rand bit [7:0] data[4];
  int            n;

  constraint c_range { x inside {[lo:hi]}; }
  constraint c_tbl   { x != tbl[0]; x != tbl[1]; }
  constraint c_iter  { foreach (mask[i]) data[i] == mask[i] + 1; }
endclass

class Hooks;
  rand bit [7:0] v;
  int pre_calls = 0;
  int post_calls = 0;
  bit make_impossible = 0;
  constraint c_imp { make_impossible -> v > 300; }   // 8 bits: unsatisfiable
  function void pre_randomize();  pre_calls++;  endfunction
  function void post_randomize(); post_calls++; endfunction
endclass

class Mixed;
  rand bit [7:0] r1;
  bit  [7:0]     s1;              // not rand: only randomize(s1) reaches it
endclass

module main;

  Pair      p;
  WithState w;
  Hooks     h;
  Mixed     m;

  int fails = 0;
  bit [7:0] a0, b0, x0;
  int ok;
  bit q;
  int seen_lo, seen_hi;

  task chk(string what, int got, int want);
    if (got !== want) begin
      fails++;
      $display("FAILED -- %s: got %0d want %0d", what, got, want);
    end
  endtask

  initial begin

    // ---------------- 18.3: state variables ----------------
    w = new();
    w.lo = 8'd40;  w.hi = 8'd44;
    w.tbl[0] = 8'd41;  w.tbl[1] = 8'd42;
    for (int i = 0; i < 4; i++) w.mask[i] = i + 10;
    seen_lo = 999; seen_hi = 0;
    for (int i = 0; i < 30; i++) begin
      if (!w.randomize()) begin
        fails++; $display("FAILED -- state-variable constraint set is UNSAT");
      end
      if (w.x < w.lo || w.x > w.hi) begin
        fails++;
        $display("FAILED -- x=%0d outside the state-variable range [%0d:%0d]",
                 w.x, w.lo, w.hi);
      end
      if (w.x == w.tbl[0] || w.x == w.tbl[1]) begin
        fails++;
        $display("FAILED -- x=%0d hit an excluded state-array element", w.x);
      end
      // the iterative constraint reads a state array element per index
      foreach (w.data[k])
        if (w.data[k] !== ((w.mask[k] + 1) & 8'hff)) begin
          fails++;
          $display("FAILED -- data[%0d]=%0d want %0d (state array in foreach)",
                   k, w.data[k], w.mask[k] + 1);
        end
      if (w.x < seen_lo) seen_lo = w.x;
      if (w.x > seen_hi) seen_hi = w.x;
    end
    // 40..44 minus 41 and 42 leaves {40, 43, 44}: the solve must move.
    if (seen_lo == seen_hi) begin
      fails++;
      $display("FAILED -- x never moved off %0d across 30 solves", seen_lo);
    end

    // a state variable must come out of randomize() untouched
    chk("state var lo unchanged",     w.lo,     8'd40);
    chk("state var hi unchanged",     w.hi,     8'd44);
    chk("state array tbl[0] unchanged", w.tbl[0], 8'd41);
    chk("state array mask[2] unchanged", w.mask[2], 8'd12);

    // ---------------- 18.8: rand_mode ----------------
    p = new();
    // the query form, before anything has touched the mode
    if (p.a.rand_mode() !== 1) begin
      fails++;
      $display("FAILED -- a.rand_mode() reads %0d for an active field (want 1)",
               p.a.rand_mode());
    end
    p.a.rand_mode(0);
    if (p.a.rand_mode() !== 0) begin
      fails++;
      $display("FAILED -- a.rand_mode() reads %0d after rand_mode(0) (want 0)",
               p.a.rand_mode());
    end

    // a frozen field keeps its value AND still constrains the rest:
    // b == a + 1 must hold with a pinned at 100.
    p.a = 8'd100;
    p.b = 8'd0;
    if (!p.randomize()) begin
      fails++; $display("FAILED -- randomize() with a frozen field went UNSAT");
    end
    chk("frozen field kept its value", p.a, 8'd100);
    chk("constraint solved against the frozen field", p.b, 8'd101);

    // re-enabling through the query result is the save/restore idiom
    q = p.a.rand_mode();
    p.a.rand_mode(1);
    if (p.a.rand_mode() !== 1) begin
      fails++; $display("FAILED -- rand_mode(1) did not re-enable the field");
    end
    if (q !== 0) begin
      fails++; $display("FAILED -- the saved mode read %0d, want 0", q);
    end

    // freezing at a value the constraints cannot accept must FAIL the
    // call and leave the object alone (18.6.1), not silently move it
    p.a = 8'd255;               // b == a+1 wraps to 0, still satisfiable
    p.a.rand_mode(0);
    w = new();                  // (fresh object below; keep p for the check)
    p.b = 8'd7;
    ok = p.randomize();
    chk("frozen field still frozen after a solve", p.a, 8'd255);
    if (ok && p.b !== 8'd0) begin
      fails++;
      $display("FAILED -- b=%0d with a frozen at 255 (want 0)", p.b);
    end
    p.a.rand_mode(1);

    // object-level rand_mode(0) freezes every rand field
    m = new();
    m.r1 = 8'd77;
    m.rand_mode(0);
    void'(m.randomize());
    chk("object-level rand_mode(0) froze r1", m.r1, 8'd77);
    m.rand_mode(1);

    // ---------------- 18.11: in-line variable control ----------------
    p = new();
    void'(p.randomize());
    a0 = p.a;  b0 = p.b;

    // statement form: only b is random, a is a state variable
    void'(p.randomize(b));
    chk("randomize(b) left a alone", p.a, a0);
    chk("randomize(b) re-solved b from the state a", p.b, (a0 + 1) & 8'hff);

    // expression form takes the same route
    ok = p.randomize(b);
    if (!ok) begin fails++; $display("FAILED -- randomize(b) returned 0"); end
    chk("expression-form randomize(b) left a alone", p.a, a0);

    // both listed: both may move
    a0 = p.a;
    seen_lo = 0;
    for (int i = 0; i < 20; i++) begin
      void'(p.randomize(a, b));
      if (p.b !== ((p.a + 1) & 8'hff)) begin
        fails++;
        $display("FAILED -- randomize(a,b) broke b==a+1: a=%0d b=%0d", p.a, p.b);
      end
      if (p.a !== a0) seen_lo = 1;
    end
    if (seen_lo == 0) begin
      fails++;
      $display("FAILED -- randomize(a, b) never moved a off %0d", a0);
    end

    // a variable that is NOT declared rand becomes random when listed
    m = new();
    m.s1 = 8'd5;
    seen_lo = 0;
    for (int i = 0; i < 20; i++) begin
      void'(m.randomize(s1));
      if (m.s1 !== 8'd5) seen_lo = 1;
    end
    if (seen_lo == 0) begin
      fails++;
      $display("FAILED -- randomize(s1) never randomized the listed non-rand field");
    end
    // ... and the rand field it did not list stays put
    m.r1 = 8'd9;
    void'(m.randomize(s1));
    chk("randomize(s1) left the unlisted rand field alone", m.r1, 8'd9);

    // randomize(null): a check that changes nothing
    p = new();
    void'(p.randomize());
    a0 = p.a;  b0 = p.b;
    ok = p.randomize(null);
    if (!ok) begin
      fails++; $display("FAILED -- randomize(null) returned 0 on a satisfied object");
    end
    chk("randomize(null) left a alone", p.a, a0);
    chk("randomize(null) left b alone", p.b, b0);

    // ... and reports UNSAT when the current values violate a constraint
    p.b = p.a;                  // breaks b == a + 1 (a+1 != a for 8 bits)
    ok = p.randomize(null);
    if (ok) begin
      fails++;
      $display("FAILED -- randomize(null) returned 1 with b==a violating b==a+1");
    end
    chk("failed randomize(null) still changed nothing", p.b, p.a);

    // ---------------- 18.6.1 / 18.6.2: the hooks ----------------
    h = new();
    h.make_impossible = 0;
    if (!h.randomize()) begin
      fails++; $display("FAILED -- the satisfiable randomize() failed");
    end
    chk("pre_randomize ran on success",  h.pre_calls,  1);
    chk("post_randomize ran on success", h.post_calls, 1);

    h.make_impossible = 1;
    x0 = h.v;
    ok = h.randomize();
    if (ok) begin
      fails++; $display("FAILED -- the unsatisfiable randomize() returned 1");
    end
    chk("pre_randomize ran on failure too", h.pre_calls,  2);
    chk("post_randomize did NOT run on failure", h.post_calls, 1);
    chk("a failed randomize() left the variable alone", h.v, x0);

    // randomize(null) runs neither hook
    h.make_impossible = 0;
    void'(h.randomize(null));
    chk("randomize(null) did not call pre_randomize",  h.pre_calls,  2);
    chk("randomize(null) did not call post_randomize", h.post_calls, 1);

    // The expression-form with-clause carries the argument list too.
    // The bare and void-cast statement siblings are pinned separately
    // by sv_object_randomize_statement_with.
    p = new();
    void'(p.randomize());
    a0 = p.a;
    ok = p.randomize(b) with { b < 8'd200; };
    if (!ok) begin
      fails++; $display("FAILED -- randomize(b) with {...} returned 0");
    end
    chk("randomize(b) with {...} left a alone", p.a, a0);
    if (p.b !== ((a0 + 1) & 8'hff)) begin
      fails++;
      $display("FAILED -- randomize(b) with {...}: b=%0d want %0d", p.b, a0 + 1);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
