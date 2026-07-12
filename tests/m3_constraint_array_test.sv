// M3 array-constraint regression: dynamic-array size constraints (G21) and
// foreach iterative constraints (G16). IEEE 1800-2017 18.5.8.
module m3_constraint_array_test;
  class SizeC;                        // G21
    rand int unsigned sz;
    rand byte arr[];
    constraint c { sz inside {[3:5]}; arr.size() == sz; }
  endclass

  class ForeachC;                     // G16
    rand int unsigned arr[4];
    constraint c { foreach (arr[i]) arr[i] inside {[i*10 : i*10+5]}; }
  endclass

  initial begin
    SizeC s = new;
    ForeachC f = new;
    int errors = 0;

    repeat (10) begin
      void'(s.randomize());
      if (!(s.sz >= 3 && s.sz <= 5 && s.arr.size() == s.sz)) begin
        $display("FAIL size sz=%0d arr.size=%0d", s.sz, s.arr.size());
        errors++;
      end
      void'(f.randomize());
      foreach (f.arr[i]) begin
        if (!(f.arr[i] >= i*10 && f.arr[i] <= i*10+5)) begin
          $display("FAIL foreach arr[%0d]=%0d", i, f.arr[i]);
          errors++;
        end
      end
    end

    if (errors == 0) $display("PASS");
    else $display("TOTAL FAILS: %0d", errors);
  end
endmodule
