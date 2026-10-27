module p20_06_bits_b3;
  typedef struct { int a; int b; } P;
  typedef struct packed { int a; int b; } PP;
  P p;
  PP pp;
  int q[2];
  initial $display("B3 %0d", $bits(q));
endmodule
