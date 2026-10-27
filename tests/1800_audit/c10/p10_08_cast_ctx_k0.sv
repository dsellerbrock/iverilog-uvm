module p10_08_cast_ctx_k0;
  typedef struct { int a; int b; } P;
  P p;
  initial begin
    p = P'{a:3, b:4};
    $display("K0 %0d %0d", p.a, p.b);
  end
endmodule
