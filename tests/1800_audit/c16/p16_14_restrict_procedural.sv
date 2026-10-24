module test;
  bit clk = 0;
  always #5 clk = ~clk;

  initial begin
    restrict property (@(posedge clk) 1'b0);
    @(posedge clk); #1;
    $display("PASSED: §16.14 procedural restrict property");
    $finish;
  end
endmodule
