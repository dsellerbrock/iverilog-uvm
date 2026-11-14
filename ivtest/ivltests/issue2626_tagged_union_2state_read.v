module tb;
  typedef union tagged { logic [7:0] L; int I; } u_t;
  u_t u;
  int k;
  logic [7:0] bits;

  initial begin
    u = tagged L 8'b1x01;
    k = u.I;
    $display("int=%0d unknown=%0d", k, $isunknown(k));

    bits = u.L;
    $display("logic=%b unknown=%0d", bits, $isunknown(bits));
  end
endmodule
