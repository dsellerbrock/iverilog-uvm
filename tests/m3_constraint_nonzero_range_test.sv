// M3 tail: foreach constraints over NON-0-BASED static rand arrays
// (IEEE 1800-2017 18.5.8.1: the loop variable ranges over the array's
// declared indices). Previously any declared range with both bounds
// nonzero was warned-and-ignored (elements left unconstrained), and
// the loop variable was bound to the canonical 0-based position even
// for [0:N-1]/[N-1:0] ranges where declared == canonical only by
// coincidence of the supported shapes.

class lohi;
  rand bit [7:0] arr[3:1];
  constraint c_elem { foreach (arr[i]) arr[i] == i * 7; }
endclass

class hilo;
  rand bit [7:0] arr[5:2];
  constraint c_elem { foreach (arr[i]) arr[i] inside {[i*10 : i*10+3]}; }
endclass

class zero_based;   // characterization: canonical == declared
  rand bit [7:0] arr[4];
  constraint c_elem { foreach (arr[i]) arr[i] == i + 100; }
endclass

module m3_constraint_nonzero_range_test;
  lohi a;
  hilo b;
  zero_based z;
  int errors = 0;

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  initial begin
    a = new;
    b = new;
    z = new;
    repeat (3) begin
      check(a.randomize() == 1, "lohi randomize");
      for (int i = 1; i <= 3; i++)
        check(a.arr[i] == i * 7, $sformatf("lohi arr[%0d]", i));

      check(b.randomize() == 1, "hilo randomize");
      for (int i = 2; i <= 5; i++)
        check(b.arr[i] >= i*10 && b.arr[i] <= i*10+3,
              $sformatf("hilo arr[%0d]", i));

      check(z.randomize() == 1, "zero_based randomize");
      for (int i = 0; i < 4; i++)
        check(z.arr[i] == i + 100, $sformatf("zero_based arr[%0d]", i));
    end

    if (errors == 0)
      $display("PASSED: all m3 non-0-based foreach range checks");
    else
      $display("FAILED: %0d m3 checks", errors);
    $finish(0);
  end
endmodule
