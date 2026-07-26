// M3B: inherited constraints are solved as ONE constraint set
// (IEEE 1800-2017 18.5.2), not class by class.
//
// The runtime used to call the solver once per class in the inheritance
// chain. Each call solved a SUBSET and wrote its answer back, so the last
// call -- the base class's -- could overwrite the full solution. Whenever
// the base-only re-solve produced a different value, the derived class's
// HARD constraint was silently violated.
//
// A `soft' constraint in the base is the sharp case, because it disables
// the solver's accept-current fast path: `soft v == 3' in the base plus a
// hard `v > 100' in the derived class returned v == 3, silently. Two
// hard constraints usually survived only because the current value
// already satisfied the base and the fast path kept it -- luck, not
// correctness.
//
// Against the pre-fix simulator case 1 printed `v=3' and case 2 `v=3'.

class soft_base;
  rand bit [7:0] v;
  constraint s { soft v == 3; }
endclass

// 1. soft base, conflicting hard derived: 18.5.14 discards the soft.
class hard_derived extends soft_base;
  constraint d { v > 100; }
endclass

// 2. same, with the soft explicitly disabled (18.5.14.1).
class disabled_soft_derived extends soft_base;
  constraint d { disable soft v; v > 100; }
endclass

// 3. a soft base with no conflict must still be honoured.
class free_derived extends soft_base;
  rand bit [7:0] w;
  constraint d { w < 5; }
endclass

// 4. three levels, each adding a hard constraint on the same property.
class lvl0;
  rand bit [7:0] v;
  constraint c0 { v inside {[10:200]}; }
endclass
class lvl1 extends lvl0;
  constraint c1 { v > 100; }
endclass
class lvl2 extends lvl1;
  constraint c2 { v < 150; }
endclass

// 5. an unsatisfiable pair across the chain must still return 0.
class unsat_base;
  rand bit [7:0] v;
  constraint b { v == 3; }
endclass
class unsat_derived extends unsat_base;
  constraint d { v > 100; }
endclass

// 6. an inline with-clause joins the same solve as the inherited soft.
class inline_derived extends soft_base;
endclass

module main;

  hard_derived          c1;
  disabled_soft_derived c2;
  free_derived          c3;
  lvl2                  c4;
  unsat_derived         c5;
  inline_derived        c6;

  int fails = 0;
  int ok;

  initial begin
    c1 = new(); c2 = new(); c3 = new(); c4 = new(); c5 = new(); c6 = new();

    for (int i = 0; i < 20; i++) begin
      ok = c1.randomize();
      if (!ok || c1.v <= 100) begin
        fails++;
        $display("FAILED 1 -- soft base vs hard derived: ok=%0d v=%0d (want >100)", ok, c1.v);
      end

      ok = c2.randomize();
      if (!ok || c2.v <= 100) begin
        fails++;
        $display("FAILED 2 -- disable soft: ok=%0d v=%0d (want >100)", ok, c2.v);
      end

      // No conflict: the soft must hold, and the derived constraint too.
      ok = c3.randomize();
      if (!ok || c3.v != 3 || c3.w >= 5) begin
        fails++;
        $display("FAILED 3 -- unconflicted soft: ok=%0d v=%0d (want 3) w=%0d (want <5)",
                 ok, c3.v, c3.w);
      end

      ok = c4.randomize();
      if (!ok || c4.v <= 100 || c4.v >= 150) begin
        fails++;
        $display("FAILED 4 -- three-level chain: ok=%0d v=%0d (want 101..149)", ok, c4.v);
      end

      ok = c5.randomize();
      if (ok) begin
        fails++;
        $display("FAILED 5 -- unsatisfiable across the chain returned ok=1 (v=%0d)", c5.v);
      end

      ok = c6.randomize() with { v > 100; };
      if (!ok || c6.v <= 100) begin
        fails++;
        $display("FAILED 6 -- inline with vs inherited soft: ok=%0d v=%0d (want >100)",
                 ok, c6.v);
      end

      if (fails > 0) break;
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end

endmodule
