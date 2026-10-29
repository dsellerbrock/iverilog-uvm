`timescale 1ns/1ps
module test;
  logic clk = 0, a = 0, b = 0;
  int failures = 0;
  always #5 clk = ~clk;

  sequence capture_first_match(local output int captured_time);
    first_match(a ##[1:2] b, captured_time = $time);
  endsequence

  property p_first_match;
    int result_time;
    @(posedge clk) a |-> (capture_first_match(result_time) ##1 result_time == 25);
  endproperty
  assert property (p_first_match) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1;
    @(negedge clk); b = 1;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);
    if (failures) $fatal(1, "sequence local output formal failures=%0d", failures);
    $display("PASSED: sequence local output formal");
    $finish(0);
  end
endmodule
