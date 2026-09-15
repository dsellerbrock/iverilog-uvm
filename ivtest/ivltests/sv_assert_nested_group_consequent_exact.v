module test;
  bit c1, c2, a=1, b=1, c=1, d=1;
  int passes, failures; time at;
  always #10 c1 = ~c1;
  initial begin #5; forever #10 c2 = ~c2; end
  assert property (@(posedge c1) a |-> @(posedge c2)
                   ((b ##1 c)[*2] ##1 d)[*2]) begin passes++; at=$time; end
                   else failures++;
  initial begin
    #11 $assertoff(0);
    #185;
    if (passes != 1 || failures != 0 || at != 195)
      $fatal(1, "consequent p=%0d f=%0d at=%0t", passes, failures, at);
    $display("PASSED"); $finish(0);
  end
endmodule
