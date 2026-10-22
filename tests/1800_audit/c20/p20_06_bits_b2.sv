module p20_06_bits_b2;
  typedef struct { int a; int b; } P;
  typedef struct packed { int a; int b; } PP;
  P p;
  PP pp;
  int q[2];
  initial $display("B2 %0d %0d", $bits(pp), $bits(PP));
endmodule
