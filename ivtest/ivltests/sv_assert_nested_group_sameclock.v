module test;
  bit clk, a=1, b=1, c;
  int passes, failures; time at;
  always #10 clk = ~clk;
  assert property (@(posedge clk) ((a ##1 b)[*2])[*2] |=> c)
    begin passes++; at=$time; end else begin failures++; at=$time; end
  initial begin
    #11 $assertoff(0);
    #158 c = 1;
    #2;
    if (passes != 1 || failures != 0 || at != 170)
      $fatal(1, "sameclock p=%0d f=%0d at=%0t", passes, failures, at);
    $display("PASSED"); $finish(0);
  end
endmodule
