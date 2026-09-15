module test;
  bit c1, c2, a=1, b=1, good=1;
  int passes, failures;
  always #10 c1 = ~c1;
  initial begin #5; forever #10 c2 = ~c2; end
  assert property (@(posedge c1) ((a ##1 b)[*0:1])[*2]
                   |=> @(posedge c2) good) passes++; else failures++;
  initial begin
    #11 $assertoff(0);
    #29 good = 0;
    #30 good = 1;
    #6;
    // Legal children are at 15, 35 and 75. A false check at 55 exposes an
    // incorrect join of an empty first copy with a nonempty second copy.
    if (passes != 1 || failures != 0) $fatal(1, "nullable p=%0d f=%0d", passes, failures);
    $display("PASSED"); $finish(0);
  end
endmodule
