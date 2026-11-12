module issue2853_bits_cast;
  typedef struct { int a; int b; } P;
  P p;

  initial begin
    p = P'('{1, 2});
    $display("bits(cast)=%0d bits(var)=%0d bits(type)=%0d",
             $bits(P'('{1, 2})), $bits(p), $bits(P));
  end
endmodule
