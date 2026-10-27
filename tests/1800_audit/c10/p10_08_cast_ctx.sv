module p10_08_cast_ctx;
  typedef struct { int a; int b; } P;
  typedef int A2[2];
  P p;
  A2 q;
  initial begin
    p = P'{a:3, b:4};             $display("K0 %0d %0d", p.a, p.b);
    p = P'('{a:5, b:6});          $display("K1 %0d %0d", p.a, p.b);
    q = A2'('{7, 8});             $display("K2 %0d %0d", q[0], q[1]);
    $display("K3 %0d", $bits(P'('{1, 2})));
  end
endmodule
