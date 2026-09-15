module test;
  bit c1, c2, a=1, b=1, c=1, good=1;
  int passes, failures;
  always #10 c1 = ~c1;
  initial begin #5; forever #10 c2 = ~c2; end
  assert property (@(posedge c1) ((a ##1 b)[*1:2] ##1 c)[*1:2]
                   |=> @(posedge c2) good) passes++; else failures++;
  initial begin
    #11 $assertoff(0);
    #143 good = 0;
    #2 good = 1;
    #40;
    if (passes != 0 || failures != 1) $fatal(1, "ranged p=%0d f=%0d", passes, failures);
    $display("PASSED"); $finish(0);
  end
endmodule
