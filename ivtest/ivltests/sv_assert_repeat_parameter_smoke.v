// Runtime witness for the parameter-valued consecutive-repetition bounds in
// OpenTitan's prim_esc_rxtx checker (IEEE 1800-2017 16.9.2 and 16.12.7).
// The declaration default is intentionally the real OpenTitan value: the
// bounded and unbounded age sets are 61 and 62 bits, not parse-time-expanded
// collections of expression nodes.
module sv_assert_repeat_parameter_smoke;
  parameter int TimeoutCntDw = 6;
  logic clk = 0;
  logic start = 0;
  logic ping = 0;
  logic esc = 1;
  logic disable_i = 0;

  integer bounded_pass = 0;
  integer bounded_fail = 0;
  integer unbounded_pass = 0;
  integer unbounded_fail = 0;

  always #1 clk = ~clk;

  bounded: assert property (@(posedge clk)
    disable iff (disable_i)
    start ##1 !ping [*0 : 2**TimeoutCntDw - 4]
    |-> ##1 !esc)
      bounded_pass += 1;
    else
      bounded_fail += 1;

  unbounded: assert property (@(posedge clk)
    disable iff (disable_i)
    start ##1 !ping [*2**TimeoutCntDw - 3 : $]
    |-> ##1 esc)
      unbounded_pass += 1;
    else
      unbounded_fail += 1;

  initial begin
    // Launch an attempt, let its empty bounded endpoint become due, then
    // disable on the verdict tick. disable iff must clear both age vectors
    // and the pending consequent without executing either action block.
    @(negedge clk) start = 1;
    @(negedge clk) begin
      start = 0;
      disable_i = 1;
    end
    @(negedge clk) disable_i = 0;
    if (bounded_pass != 0 || bounded_fail != 0 ||
        unbounded_pass != 0 || unbounded_fail != 0) begin
      $display("FAILED: disable iff did not cancel parameter repetition state");
      $finish_and_return(1);
    end

    // Two adjacent starts exercise overlapping attempts. With !ping held,
    // every bounded endpoint remains live through length 60 and every
    // unbounded endpoint remains live from length 61 onward.
    @(negedge clk) start = 1;
    @(negedge clk) start = 1;
    @(negedge clk) start = 0;
    repeat (66) @(negedge clk);

    $display("COUNTS bounded=%0d/%0d unbounded=%0d/%0d",
             bounded_pass, bounded_fail, unbounded_pass, unbounded_fail);
    if (bounded_pass != 0 || bounded_fail != 122) begin
      $display("FAILED: bounded repetition missed or extended an endpoint");
      $finish_and_return(1);
    end
    if (unbounded_pass != 11 || unbounded_fail != 0) begin
      $display("FAILED: unbounded repetition did not preserve every endpoint");
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
