// M3 tail: solve...before variable ordering (IEEE 1800-2017 18.5.10).
// Previously parsed-and-dropped. Now each `solve A before B` emits an
// (order ...) IR directive and %randomize solves in ranked stages:
// the `before` variables get the value-diversity objective in an
// earlier stage and are pinned for the later stages. Ordering affects
// distribution only, never satisfiability.
//
// Distribution checks use LOOSE bounds so the test is not seed-flaky:
// the pre-fix failure mode was extreme (a==1 essentially never chosen
// in the implication shape), far outside these bounds.

class impl_order;      // the G11/G57 shape
  rand bit a;
  rand bit [3:0] b;
  constraint c1 { a -> b == 7; }
  constraint c2 { solve a before b; }
endclass

class chain_order;     // transitive chain of orderings
  rand bit [3:0] x, y, z;
  constraint c1 { y > x; z > y; }
  constraint c2 { solve x before y; solve y before z; }
endclass

module m3_constraint_solve_before_test;
  impl_order c;
  chain_order d;
  int errors = 0;
  int a1, i;
  int bvals[16];
  int distinct;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    c = new;
    a1 = 0;
    for (i = 0; i < 150; i++) begin
      check(c.randomize() == 1, "impl_order randomize");
      if (c.a) begin
        a1++;
        check(c.b == 7, $sformatf("implication violated: a=1 b=%0d", c.b));
      end
      else bvals[c.b]++;
    end
    // a should be roughly uniform (pre-fix: a==1 was ~6% of draws).
    check(a1 >= 30 && a1 <= 120,
          $sformatf("a distribution a1=%0d/150 outside [30,120]", a1));
    // b should stay diverse when unconstrained (a==0).
    distinct = 0;
    for (i = 0; i < 16; i++) if (bvals[i] > 0) distinct++;
    check(distinct >= 4,
          $sformatf("b diversity when a==0: %0d distinct values", distinct));

    d = new;
    for (i = 0; i < 30; i++) begin
      check(d.randomize() == 1, "chain_order randomize");
      check(d.y > d.x && d.z > d.y,
            $sformatf("chain violated x=%0d y=%0d z=%0d", d.x, d.y, d.z));
    end

    if (errors == 0)
      $display("PASSED: all m3 solve...before checks");
    else
      $display("FAILED: %0d m3 solve...before checks", errors);
    $finish(0);
  end
endmodule
