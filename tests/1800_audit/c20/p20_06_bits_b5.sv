module p20_06_bits_b5;
  typedef struct { int a; int b; } P;
  typedef struct packed { int a; int b; } PP;
  P p;
  PP pp;
  int q[2];
  initial $display("B5 %0d", $bits(P'(p)));
endmodule
