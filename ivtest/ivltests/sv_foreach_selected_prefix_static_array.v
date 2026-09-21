// A `foreach' selector prefix (IEEE 1800-2017/2023 12.7.3) into a
// PLAIN STATIC (non-associative) unpacked array must select the
// leading dimension and iterate the REMAINING one, not silently
// iterate the wrong (already-fixed) dimension. This is a real,
// discriminating-population runtime check: two different selector
// values must each iterate the SAME remaining dimension (size 3),
// never the fixed one (size 2) -- a prior version of the DD-040
// associative-array selector fix accidentally forced this shape
// through an expression-elaboration route that cannot partially index
// a plain signal, breaking it outright; before that, it silently
// iterated dimension 0 regardless of the selector.
module main;
  int A[2][3];
  int fails;

  initial begin
    begin
      int seen;
      seen = 0;
      foreach (A[0][j]) begin
        seen++;
        if (j < 0 || j > 2) fails++;
      end
      if (seen != 3) fails++;
    end

    begin
      int seen;
      seen = 0;
      foreach (A[1][k]) begin
        seen++;
        if (k < 0 || k > 2) fails++;
      end
      if (seen != 3) fails++;
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED, fails=%0d", fails);
    $finish;
  end
endmodule
