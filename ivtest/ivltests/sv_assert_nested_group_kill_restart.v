module test;
  bit c1, c2, a=1, b=1, good=1;
  int passes, failures; time at;
  always #10 c1 = ~c1;
  initial begin #95 c2=1; #1 c2=0; #39 c2=1; #1 c2=0; end
  assert property (@(posedge c1) ((a ##1 b)[*1])[*2]
                   |=> @(posedge c2) good) begin passes++; at=$time; end
                   else failures++;
  initial begin
    #31 $assertkill(0);
    #20 $asserton(0);
    #20 $assertoff(0);
    #70;
    if (passes != 1 || failures != 0 || at != 135)
      $fatal(1, "kill p=%0d f=%0d at=%0t", passes, failures, at);
    $display("PASSED"); $finish(0);
  end
endmodule
