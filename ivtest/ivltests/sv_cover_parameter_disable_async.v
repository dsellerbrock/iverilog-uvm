// IEEE 1800-2017 16.12: disable iff is asynchronous.  A true pulse wholly
// between assertion clocks must kill a live parameter-sized cover attempt,
// without erasing matches recorded before the pulse.  A later attempt proves
// that deassertion permits fresh evaluation rather than leaving the checker
// permanently disabled.
module cover_parameter_disable_checker #(
  parameter int N = 7,
  parameter int W = 9
) (
  input logic clk,
  input logic start,
  input logic keep,
  input logic result,
  input logic disable_i
);
  checked: cover property (@(posedge clk)
    disable iff (disable_i)
    start ##1 keep[*N] |-> ##[0:W] result);
endmodule

module sv_cover_parameter_disable_async;
  logic clk = 0;
  logic start = 0;
  logic keep = 1;
  logic result = 0;
  logic disable_i = 0;

  cover_parameter_disable_checker #(.N(1), .W(2)) dut (.*);

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    // First attempt matches at the zero endpoint of its [0:2] window.
    start = 1;
    tick();
    start = 0;
    result = 1;
    tick();
    if (dut._ivl_sva0_cnt0 !== 1) begin
      $display("FAILED: pre-disable cover count was %0d, expected 1",
               dut._ivl_sva0_cnt0);
      $finish_and_return(1);
    end

    // The second endpoint opens a live consequence window with result false.
    start = 1;
    result = 0;
    tick();
    start = 0;
    tick();

    // Abort that window entirely between clocks.  Result would match it on
    // the next clock if the asynchronous clear were missing.
    #1 disable_i = 1;
    #1 disable_i = 0;
    result = 1;
    tick();
    if (dut._ivl_sva0_cnt0 !== 1) begin
      $display("FAILED: off-clock disable changed count to %0d, expected 1",
               dut._ivl_sva0_cnt0);
      $finish_and_return(1);
    end

    // A fresh post-disable attempt must still be able to match.
    start = 1;
    result = 0;
    tick();
    start = 0;
    tick();
    result = 1;
    tick();
    if (dut._ivl_sva0_cnt0 !== 2) begin
      $display("FAILED: final cover count was %0d, expected 2",
               dut._ivl_sva0_cnt0);
      $finish_and_return(1);
    end

    $display("PASSED");
    $finish;
  end
endmodule
