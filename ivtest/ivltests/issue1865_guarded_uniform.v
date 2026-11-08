// Issue #1865: equalities under if / else-if guards must solve promptly and
// sample uniformly over all legal value combinations.
//
// IEEE 1800-2023 18.5.9 (1800-2017 18.5.10): "The solver shall assure that
// the random values are selected to give a uniform value distribution over
// legal value combinations (that is, all combinations of legal values have
// the same probability of being the solution)." 18.5.6 and 18.6.3: every
// branch here is satisfiable, so randomize() returns 1.
//
// class a: p=1 has 5 solutions, p=0 has 11 * 2**32, so P(p=1) per draw is
// about 1.1e-10. class b: m=0 has 2**32 solutions, m=1 has 11 and m=2 has 1,
// so P(m!=0) is about 2.8e-9. The old sampler drew p=1 and m!=0 in roughly
// half of all calls.
//
// The draws use fixed seeds, so the run is deterministic. For an arbitrary
// seed the bounds below fail a correct uniform sampler with probability
// below 1e-6: 200 draws of p=0 / m=0 (about 6e-7), every y value in 20..30
// seen (at most 11 * (10/11)**200, about 6e-8), and at least 190 distinct
// x / v values among 200 draws from 2**32 (collision odds below 1e-15).
class guarded_a;
  rand int x, y;
  rand bit p;
  constraint c { if (p) { x inside {[5:9]}; y == x + 1; } else { y inside {[20:30]}; } }
endclass

class guarded_b;
  rand int unsigned u, v;
  rand bit [1:0] m;
  constraint c { m != 3;
    if (m == 1) { u inside {[100:110]}; if (u > 105) v == u * 2; else v == 7; }
    else if (m == 2) { v == 3; u == v + 1000; } else { u == 0; } }
endclass

module issue1865_guarded_uniform;
  guarded_a a;
  guarded_b b;
  int failed = 0;
  int seen_y[int];
  int distinct_x[int];
  int distinct_v[int];

  initial begin
    a = new;
    b = new;
    a.srandom(32'h1865_0001);
    b.srandom(32'h1865_0002);
    repeat (200) begin
      if (!a.randomize()) begin $display("FAILED: a.randomize() returned 0"); failed++; end
      if (a.p ? !(a.x inside {[5:9]} && a.y == a.x + 1) : !(a.y inside {[20:30]})) begin
        $display("FAILED: a violates its constraint: p=%0d x=%0d y=%0d", a.p, a.x, a.y);
        failed++;
      end
      if (a.p) begin $display("FAILED: a drew p=1 (x=%0d y=%0d)", a.x, a.y); failed++; end
      seen_y[a.y] = 1;
      distinct_x[a.x] = 1;

      if (!b.randomize()) begin $display("FAILED: b.randomize() returned 0"); failed++; end
      if (b.m == 3
          || (b.m == 1 && !(b.u inside {[100:110]} && b.v == (b.u > 105 ? b.u * 2 : 7)))
          || (b.m == 2 && !(b.v == 3 && b.u == 1003))
          || (b.m == 0 && b.u != 0)) begin
        $display("FAILED: b violates its constraint: m=%0d u=%0d v=%0d", b.m, b.u, b.v);
        failed++;
      end
      if (b.m != 0) begin $display("FAILED: b drew m=%0d (u=%0d v=%0d)", b.m, b.u, b.v); failed++; end
      distinct_v[b.v] = 1;
    end
    if (seen_y.num() != 11) begin $display("FAILED: a saw %0d of the 11 y values", seen_y.num()); failed++; end
    if (distinct_x.num() < 190) begin $display("FAILED: a drew only %0d distinct x", distinct_x.num()); failed++; end
    if (distinct_v.num() < 190) begin $display("FAILED: b drew only %0d distinct v", distinct_v.num()); failed++; end
    if (failed == 0) $display("PASSED");
  end
endmodule
