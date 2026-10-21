`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic value = 0;
  int checks = 0;
  int failures = 0;
  always #5 clk = ~clk;

  always @(posedge clk) begin
    logic sampled_before;
    sampled_before = $sampled(value);
    value = ~value;
    if ($sampled(value) !== sampled_before) begin
      failures++;
      $display("GAP: $sampled changed within the time step: before=%b after=%b",
               sampled_before, $sampled(value));
    end
    checks++;
  end

  initial begin
    repeat (2) @(negedge clk);
    if (failures == 0) begin
      $display("PASSED: $sampled preserves the time-step sample in procedural code");
    end else begin
      $display("RESULT: failures=%0d checks=%0d", failures, checks);
    end
    $finish(0);
  end
endmodule
