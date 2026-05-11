// Regression: obj.<cname>.constraint_mode() as a 0-arg query function.
// Returns 1 when the named constraint block is enabled, 0 when disabled.
// Without this elaboration path the call falls into a compile-progress
// "no method" stub that returns 0, masking real test failures.

class A;
   rand int x;
   constraint c1 { x < 0; }
   constraint c2 { x > 0; }
endclass

module top;
   A a;
   int r1_before, r2_before, r1_after, r2_after;
   int ok;

   initial begin
      a = new;
      r1_before = a.c1.constraint_mode();   // default = enabled = 1
      r2_before = a.c2.constraint_mode();
      a.c1.constraint_mode(0);              // disable c1
      r1_after = a.c1.constraint_mode();    // expect 0
      r2_after = a.c2.constraint_mode();    // expect 1 (untouched)
      ok = (r1_before == 1) && (r2_before == 1)
        && (r1_after  == 0) && (r2_after  == 1);
      if (ok) $display("PASSED");
      else $display("FAILED r1_b=%0d r2_b=%0d r1_a=%0d r2_a=%0d",
                    r1_before, r2_before, r1_after, r2_after);
      $finish;
   end
endmodule
