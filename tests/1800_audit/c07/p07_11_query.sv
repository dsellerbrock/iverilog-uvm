module p07_11_query;
  logic [3:0][7:0] p;
  int u[2:5][0:1];
  int dyn[];
  int q[$] = '{1,2};
  initial begin
    dyn = new[3];
    $display("D %0d %0d %0d %0d", $dimensions(p), $unpacked_dimensions(p), $dimensions(u), $unpacked_dimensions(u));
    $display("U1 %0d %0d %0d %0d %0d %0d", $left(u), $right(u), $low(u), $high(u), $increment(u), $size(u));
    $display("U2 %0d %0d %0d %0d", $left(u,2), $right(u,2), $increment(u,2), $size(u,2));
    $display("P %0d %0d %0d %0d", $left(p), $increment(p), $size(p), $size(p,2));
    $display("Y %0d %0d %0d %0d", $size(dyn), $left(dyn), $right(dyn), $right(q));
    $display("X %b", $left(u,5));
  end
endmodule
