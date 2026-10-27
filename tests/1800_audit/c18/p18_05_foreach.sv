class C1; rand byte A[]; constraint c1 { A.size == 4; } constraint c2 { foreach (A[i]) A[i] inside {2,4,8,16}; } endclass
class C2; rand int A[]; constraint c1 { A.size inside {[1:10]}; } constraint c2 { foreach (A[k]) (k < A.size - 1) -> A[k+1] > A[k]; } endclass
class C3; rand bit [7:0] A[]; constraint c1 { A.size == 5; } constraint c2 { A.sum() with (int'(item)) < 1000; } endclass
class C4; rand int M[2][3]; constraint c { foreach (M[i,j]) M[i][j] == i*10 + j; } endclass
class C5; rand byte A[]; constraint c1 { A.size == 4; } constraint c2 { foreach (A[j]) A[j] > 2*j; } endclass
module p18f;
 int pass=0, fail=0; task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
 C1 c1 = new; C2 c2 = new; C3 c3 = new; C4 c4 = new; C5 c5 = new; int r, ok1, ok2, ok3, ok4, ok5, sz_ok, total;
 initial begin
  ok1 = 1; ok2 = 1; ok3 = 1; ok5 = 1; sz_ok = 1;
  repeat (20) begin
   r = c1.randomize(); foreach (c1.A[i]) if (!(c1.A[i] inside {2,4,8,16})) ok1 = 0; if (r != 1 || c1.A.size() != 4) ok1 = 0;
   r = c2.randomize(); if (r != 1 || c2.A.size() < 1 || c2.A.size() > 10) sz_ok = 0; foreach (c2.A[k]) if (k < c2.A.size() - 1 && !(c2.A[k+1] > c2.A[k])) ok2 = 0;
   r = c3.randomize(); total = 0; foreach (c3.A[i]) total += int'(c3.A[i]); if (r != 1 || total >= 1000) ok3 = 0;
   r = c5.randomize(); foreach (c5.A[j]) if (!(c5.A[j] > 2*j)) ok5 = 0; if (r != 1) ok5 = 0;
  end
  r = c4.randomize(); ok4 = (r == 1); for (int i=0;i<2;i++) for (int j=0;j<3;j++) if (c4.M[i][j] != i*10 + j) ok4 = 0;
  ck("foreach_set", ok1); ck("foreach_size", sz_ok); ck("foreach_guard_ascending", ok2); ck("reduction_sum", ok3); ck("foreach_2d", ok4); ck("foreach_index_expr", ok5);
  $display("RESULT pass=%0d fail=%0d", pass, fail); end
endmodule
