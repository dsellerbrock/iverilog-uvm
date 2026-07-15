// M3 tail: foreach constraints over DYNAMIC arrays and queues
// (IEEE 1800-2017 18.5.8.2). Previously any foreach constraint over a
// dynamic-array/queue rand property was warned-and-ignored: the size
// solved (G21) but the elements were raw random bits.
//
// Mechanism under test: the constraint compiles to a runtime template
// `(dynforeach ...)`; %randomize solves in two passes — sizes first
// (18.5.8.2: "the size ... is solved before the iterative
// constraints"), then the templates expand to the solved element
// count and everything re-solves with the sizes pinned.

class fixed_size;    // size pinned by equality, index arithmetic
  rand int da[];
  constraint c_size { da.size() == 4; }
  constraint c_elem { foreach (da[i]) da[i] inside {[i*10 : i*10+5]}; }
endclass

class ranged_size;   // size ranged, elements coupled to a rand scalar
  rand int unsigned da[];
  rand bit [7:0] base;
  constraint c_size { da.size() inside {[2:5]}; base > 10; }
  constraint c_elem { foreach (da[i]) da[i] == base + i; }
endclass

class queue_prop;    // queue property, size from procedural code
  rand bit [15:0] q[$];
  constraint c_elem { foreach (q[i]) q[i] inside {[100:110]}; }
endclass

class free_size;     // no size constraint: size stays as allocated
  rand int da[];
  constraint c_elem { foreach (da[i]) da[i] == i * 5; }
endclass

module m3_constraint_dynforeach_test;
  fixed_size  f;
  ranged_size r;
  queue_prop  qp;
  free_size   fs;
  int errors = 0;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    f = new;
    repeat (4) begin
      check(f.randomize() == 1, "fixed_size randomize");
      check(f.da.size() == 4, "fixed_size size");
      foreach (f.da[i])
        check(f.da[i] >= i*10 && f.da[i] <= i*10+5,
              $sformatf("fixed_size da[%0d]=%0d", i, f.da[i]));
    end

    r = new;
    repeat (4) begin
      check(r.randomize() == 1, "ranged_size randomize");
      check(r.da.size() >= 2 && r.da.size() <= 5, "ranged_size size");
      check(r.base > 10, "ranged_size base");
      foreach (r.da[i])
        check(r.da[i] == r.base + i,
              $sformatf("ranged_size da[%0d]=%0d base=%0d", i, r.da[i], r.base));
    end

    qp = new;
    qp.q.push_back(0); qp.q.push_back(0); qp.q.push_back(0);
    check(qp.randomize() == 1, "queue_prop randomize");
    check(qp.q.size() == 3, "queue_prop size preserved");
    foreach (qp.q[i])
      check(qp.q[i] >= 100 && qp.q[i] <= 110,
            $sformatf("queue_prop q[%0d]=%0d", i, qp.q[i]));

    fs = new;
    fs.da = new[4];
    check(fs.randomize() == 1, "free_size randomize");
    check(fs.da.size() == 4, "free_size size preserved");
    foreach (fs.da[i])
      check(fs.da[i] == i*5, $sformatf("free_size da[%0d]=%0d", i, fs.da[i]));

    if (errors == 0)
      $display("PASSED: all m3 dynamic foreach constraint checks");
    else
      $display("FAILED: %0d m3 dynforeach checks", errors);
    $finish(0);
  end
endmodule
