module test;
  bit clk = 0;
  always #5 clk = ~clk;

  restrict property (@(posedge clk) 1'b0);

  initial begin
    @(posedge clk); #1;
    $display("PASSED: §16.14 module-item restrict property is simulation-inert");
    $finish;
  end
endmodule
