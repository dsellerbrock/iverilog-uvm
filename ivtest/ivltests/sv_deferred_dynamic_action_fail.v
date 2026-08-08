// Legal call shape, but Stage 1 cannot yet capture dynamic input arguments at
// assertion execution. It must refuse loudly instead of reading x in Reactive.
module t;
  int x = 7;
  initial assert #0 (0) else $display("x=%0d", x);
endmodule
