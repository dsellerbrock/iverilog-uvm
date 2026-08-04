// IEEE 1800-2017 16.9.2: named sequences may contain a consecutive
// repetition whose bound is an overridable parameter, and a nonoverlapped
// implication may use another parameter expression as a bounded window.
// Both expressions must resolve independently for every interface instance.
interface named_parameter_repeat_window_if #(
  parameter int RiseMin = 8,
  parameter int RiseMax = 12
) (
  input logic clk,
  input logic cause,
  input logic result
);
  integer passes = 0;
  integer failures = 0;

  sequence CauseReady_S;
    $rose(cause) ##1 cause [* RiseMin];
  endsequence

  A: assert property (@(posedge clk)
      CauseReady_S |=> ##[0:RiseMax-RiseMin] result)
    passes += 1;
  else
    failures += 1;
endinterface

module sv_assert_named_parameter_repeat_window;
  logic clk = 0;
  logic cause_one = 0;
  logic result_one = 0;
  logic cause_three = 0;
  logic result_three = 0;

  always #5 clk = ~clk;

  named_parameter_repeat_window_if #(.RiseMin(1), .RiseMax(2))
      one (clk, cause_one, result_one);
  named_parameter_repeat_window_if #(.RiseMin(3), .RiseMax(5))
      three (clk, cause_three, result_three);

  task automatic drive(input logic c1, input logic r1,
                       input logic c3, input logic r3);
    @(negedge clk);
    cause_one = c1;
    result_one = r1;
    cause_three = c3;
    result_three = r3;
  endtask

  initial begin
    // First launch: [*1] ends at c2 and its [0:1] window matches at c4.
    // [*3] ends at c4 and its [0:2] window matches at c6.
    drive(1, 0, 1, 0); // c1: $rose launches
    drive(1, 0, 1, 0); // c2
    drive(0, 0, 1, 0); // c3
    drive(0, 1, 1, 0); // c4
    drive(0, 0, 0, 0); // c5
    drive(0, 0, 0, 1); // c6
    drive(0, 0, 0, 0); // c7

    // Second launch has no result. [*1] expires at c11; [*3] expires
    // at c14. This checks the inclusive upper endpoint and failure path.
    drive(1, 0, 1, 0); // c8
    drive(1, 0, 1, 0); // c9
    drive(0, 0, 1, 0); // c10
    drive(0, 0, 1, 0); // c11
    drive(0, 0, 0, 0); // c12
    drive(0, 0, 0, 0); // c13
    drive(0, 0, 0, 0); // c14
    drive(0, 0, 0, 0); // c15 / flush
    @(negedge clk);

    if (one.passes != 1 || one.failures != 1)
      $display("FAILED -- RiseMin/Max=1/2 got %0d/%0d",
               one.passes, one.failures);
    else if (three.passes != 1 || three.failures != 1)
      $display("FAILED -- RiseMin/Max=3/5 got %0d/%0d",
               three.passes, three.failures);
    else
      $display("PASSED");
    $finish;
  end
endmodule
