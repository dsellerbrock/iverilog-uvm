// Phase 81 follow-up regression: mixed `arr.sum()` and per-element
// `arr[i]` references on the same unpacked-array property must use a
// consistent flat-bitvector width in the constraint IR.  Without the
// fix at elaborate.cc:10800, the bare-PEIdent path emitted `p:idx:32`
// (scalar default) while the sum-fold emitted `p:idx:flat`, and
// vvp_z3.cc::get_prop_var deduped by idx — first-wins, second silently
// width-truncated.  This test exercises both shapes against the same
// property; without the fix the constraint becomes unsolvable or
// solver-trivial.

class A;
   rand int B[4];
   // Constrain element 0 to a specific value AND sum to a specific total.
   constraint c_elem { B[0] == 7; }
   constraint c_sum  { B.sum() == 100; }
endclass

module top;
   A a;
   int ok;
   initial begin
      a = new;
      void'(a.randomize());
      ok = (a.B[0] == 7) && (a.B[0] + a.B[1] + a.B[2] + a.B[3] == 100);
      if (ok)
         $display("PASSED B=%0d %0d %0d %0d", a.B[0], a.B[1], a.B[2], a.B[3]);
      else
         $display("FAILED B=%0d %0d %0d %0d sum=%0d",
                  a.B[0], a.B[1], a.B[2], a.B[3],
                  a.B[0] + a.B[1] + a.B[2] + a.B[3]);
      $finish;
   end
endmodule
