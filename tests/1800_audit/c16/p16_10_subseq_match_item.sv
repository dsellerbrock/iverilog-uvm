module test;
  logic clk = 0, a = 0, b = 0;
  int failures = 0;
  always #5 clk = ~clk;

  property p_subseq;
    int x;
    @(posedge clk) ((a ##1 b), x = 1) |-> ##1 (x == 1);
  endproperty
  assert property (p_subseq) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 0;
    repeat (3) @(negedge clk);
    if (failures != 0) $fatal(1, "compound sequence match-item failures=%0d", failures);
    $display("PASSED: §16.10 match item on compound sequence");
    $finish(0);
  end
endmodule
