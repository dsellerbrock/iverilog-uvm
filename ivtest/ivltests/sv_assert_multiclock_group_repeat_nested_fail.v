module test;
  bit c1, c2, a=1, b=1, c=1, good;
  int passes, failures; time at;
  always #10 c1 = ~c1;
  initial begin #5; forever #10 c2 = ~c2; end
  assert property (@(posedge c1) ((a ##1 b)[*2] ##1 c)[*2]
                   |=> @(posedge c2) good) begin passes++; at=$time; end
                   else begin failures++; at=$time; end
  initial begin
    #11 $assertoff(0);
    #185;
    if (passes != 0 || failures != 1 || at != 195)
      $fatal(1, "nested runtime failure p=%0d f=%0d at=%0t", passes, failures, at);
    $display("PASSED"); $finish(0);
  end
endmodule
