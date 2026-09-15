module test;
  bit c1, c2, a=1, b=1, good;
  int passes, failures; time at;
  always #1 c1 = ~c1;
  initial begin
    #65 c2=1; #1 c2=0;
    #62 good=1; #1 c2=1; #1 c2=0;
  end
  assert property (@(posedge c1) ((a ##1 b)[*2])[*16]
                   |-> @(posedge c2) good) begin passes++; at=$time; end
                   else failures++;
  initial begin
    #2 $assertoff(0); #130;
    if (passes != 1 || failures != 0 || at != 129)
      $fatal(1, "bound p=%0d f=%0d at=%0t", passes, failures, at);
    $display("PASSED"); $finish(0);
  end
endmodule
