// A concurrent assertion's repetition bounds are evaluated in the
// elaborated module instance, after parameter overrides (IEEE 1800-2017
// 6.20.2 and 16.9.2).  The large default deliberately mirrors OpenTitan's
// prim_esc_rxtx_assert_fpv; only the overridden value may size the checker.
module repeat_parameter_checker #(
  parameter int Depth = 32
) (
  input logic clk,
  input logic start,
  input logic keep,
  input logic result,
  input logic disable_i
);
  integer bounded_pass = 0;
  integer bounded_fail = 0;
  integer unbounded_pass = 0;
  integer unbounded_fail = 0;

  bounded: assert property (@(posedge clk)
    disable iff (disable_i)
    start ##1 keep [*0 : 2**Depth - 4]
    |-> ##1 result)
      bounded_pass += 1;
    else
      bounded_fail += 1;

  unbounded: assert property (@(posedge clk)
    disable iff (disable_i)
    start ##1 keep [*2**Depth - 3 : $]
    |-> ##1 result)
      unbounded_pass += 1;
    else
      unbounded_fail += 1;
endmodule

module sv_assert_repeat_parameter_override;
  logic clk = 0;
  logic start = 0;
  logic keep = 1;
  logic result = 1;
  logic disable_i = 0;

  always #1 clk = ~clk;

  // The elaborated bounds are [*0:4] and [*5:$], not approximately
  // four billion repetitions from the declaration's default value.
  repeat_parameter_checker #(.Depth(3)) dut (.*);

  initial begin
    @(negedge clk) start = 1;
    @(negedge clk) start = 0;

    // Depth=3 elaborates the bounded upper as four and the unbounded lower
    // as five.  Keep is held high long enough to exercise every bounded
    // endpoint and several unbounded endpoints.  A low result after the
    // bounded window proves the declaration default (Depth=32) was not used.
    repeat (5) @(negedge clk);
    result = 0;
    @(negedge clk);
    result = 1;
    repeat (2) @(negedge clk);

    $display("COUNTS bounded=%0d/%0d unbounded=%0d/%0d",
             dut.bounded_pass, dut.bounded_fail,
             dut.unbounded_pass, dut.unbounded_fail);
    if (dut.bounded_pass != 5 || dut.bounded_fail != 0) begin
      $display("FAILED: instance override was not used for every bounded endpoint");
      $finish_and_return(1);
    end
    if (dut.unbounded_pass != 2 || dut.unbounded_fail != 1) begin
      $display("FAILED: unbounded repetition did not create an obligation at every endpoint");
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
