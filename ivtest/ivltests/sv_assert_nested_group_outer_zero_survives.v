module test;
  bit c1, c2, a=1, b=1, c=1, good=1;
  int passes, failures;
  always #10 c1 = ~c1;
  initial begin #5; forever #10 c2 = ~c2; end
  assert property (@(posedge c1) (a ##0 (b ##1 c)[*0])[*0:1]
                   |=> @(posedge c2) good) passes++; else failures++;
  initial begin
    #11 $assertoff(0);
    #5;
    if (passes != 1 || failures != 0) $fatal(1, "outer-zero p=%0d f=%0d", passes, failures);
    $display("PASSED"); $finish(0);
  end
endmodule
