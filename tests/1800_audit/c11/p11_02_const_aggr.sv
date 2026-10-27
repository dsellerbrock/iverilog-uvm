module p11_02_const_aggr;
  function automatic int dbl(int x); return x * 2; endfunction
  localparam int W = $clog2(17);
  localparam int F = dbl(3);
  logic [F-1:0] v;
  typedef struct { int a; byte b; } S;
  int A[3] = '{1,2,3}, B[3] = '{1,2,3}, C[3] = '{1,9,3}, D[3];
  S s1 = '{1, 2}, s2 = '{1, 2}, s3 = '{1, 3}, s4;
  bit c;
  initial begin
    $display("K %0d %0d %0d", W, F, $bits(v));
    $display("E %0d %0d %0d %0d", A == B, A != C, s1 == s2, s1 != s3);
    D = A; D[1] = 7; $display("Y %0d %0d", A[1], D[1]);
    c = 1; D = c ? A : C; $display("Q1 %0d", D[1]);
    c = 0; s4 = c ? s1 : s3; $display("Q2 %0d", s4.b);
  end
endmodule
