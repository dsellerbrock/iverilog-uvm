module test;
  bit c1 = 0, c2 = 0, a = 0, x = 1, b = 0;
  int p = 0, f = 0, pt = -1;
  always #10 c1 = ~c1;
  initial begin #5; forever #10 c2 = ~c2; end
  sp: assert property (@(posedge c1) a ##[1:2] x ##1 @(posedge c2) b)
    begin p++; pt = $time; end else f++;
  initial begin
    #9 a = 1; #2 a = 0; $assertoff(0, sp);
    #29 b = 1;
    #40;
    if (p != 1 || f != 0 || pt != 55)
      $fatal(1, "p%0d f%0d pt%0d", p, f, pt);
    $display("PASSED");
    $finish(0);
  end
endmodule
