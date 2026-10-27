module p20_06_bits_struct;
  typedef struct { int a; int b; } P;
  typedef struct packed { int a; int b; } PP;
  P p;
  PP pp;
  int q[2];
  initial begin
    $display("B1 %0d %0d", $bits(p), $bits(P));
    $display("B2 %0d %0d", $bits(pp), $bits(PP));
    $display("B3 %0d %0d", $bits(q), $bits(P'{1, 2}));
    $display("B4 %0d", $bits(P'(p)));
    $display("B5 %0d", $bits(real));
  end
endmodule
