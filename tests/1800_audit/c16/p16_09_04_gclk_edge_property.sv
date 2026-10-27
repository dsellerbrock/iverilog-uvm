`timescale 1ns/1ps
module test;
  logic clk = 0;
  logic sig = 0;
  int rose_failures = 0;
  int stable_failures = 0;
  int fell_failures = 0;

  always #5 clk = ~clk;
  global clocking gclk @(posedge clk); endclocking

  assert property (@($global_clock) sig |-> $rose_gclk(sig))
    else begin rose_failures++; $display("FAILED: $rose_gclk did not detect sampled rise"); end
  assert property (@($global_clock) (sig ##1 sig) |-> $stable_gclk(sig))
    else begin stable_failures++; $display("FAILED: $stable_gclk did not detect stable samples"); end
  assert property (@($global_clock) (sig ##1 !sig) |-> $fell_gclk(sig))
    else begin fell_failures++; $display("FAILED: $fell_gclk did not detect sampled fall"); end

  initial begin
    @(negedge clk); sig = 1;
    @(negedge clk);
    @(negedge clk); sig = 0;
    #10;
    $display("observed failures: rose=%0d stable=%0d fell=%0d",
             rose_failures, stable_failures, fell_failures);
    if (rose_failures == 0 || stable_failures == 0 || fell_failures == 0)
      $fatal(1, "edge-function property probe did not exercise every function");
    $fatal(1, "§16.9.4 global edge-function behavior is nonconforming");
  end
endmodule
