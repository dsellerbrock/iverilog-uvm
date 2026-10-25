module p20_06_bits_b4;
  typedef struct { int a; int b; } P;
  typedef struct packed { int a; int b; } PP;
  P p;
  PP pp;
  int q[2];
  initial $display("B4 %0d", $bits(P'{1, 2}));
endmodule
