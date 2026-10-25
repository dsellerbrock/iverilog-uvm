module p07_12_5_map;
  int A[] = '{1,2,3}, B[] = '{2,3,5}, C[$]; bit Compare[];
  int aa[string]; int am[string]; int lo[3:5]; byte lm[3:5];
  initial begin
    A = A.map() with (item + 1'b1);            $display("M1 %0d %0d %0d", A[0], A[1], A[2]);
    C = A.map(a) with (a + B[a.index]);        $display("M2 %0d %0d %0d", C[0], C[1], C[2]);
    Compare = A.map(a) with (a == B[a.index]); $display("M3 %0d %0d %0d %0d", Compare[0], Compare[1], Compare[2], $bits(Compare[0]));
    aa = '{"x":1, "y":2}; am = aa.map() with (item * 10); $display("M4 %0d %0d %0d", am.size(), am["x"], am["y"]);
    lo = '{7, 8, 9}; lm = lo.map() with (byte'(item)); $display("M5 %0d %0d %0d", $left(lm), $right(lm), lm[4]);
  end
endmodule
