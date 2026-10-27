module test;
  bit clk = 0;
  bit start, a, b;
  int weak_failures, strong_failures;

  always #5 clk = ~clk;

  assert property (@(posedge clk) start |-> weak(a ##1 b))
    else weak_failures++;
  assert property (@(posedge clk) start |-> strong(a ##1 b))
    else strong_failures++;

  initial begin
    @(negedge clk); start = 1; a = 1;
    @(negedge clk); start = 0; a = 0; b = 1;
    @(posedge clk); #1;
    @(negedge clk); start = 1; a = 1; b = 0;
    @(posedge clk); #1;
    #1;
    $display("ENDING: completed attempt plus pending weak/strong attempt");
    $finish;
  end

  final begin
    $display("OBSERVED: weak_failures=%0d strong_failures=%0d", weak_failures,
             strong_failures);
    $display("EXPECTED: weak_failures=0 strong_failures=1");
  end
endmodule
