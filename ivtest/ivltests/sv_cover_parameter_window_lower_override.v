// Consequence-window LO and HI are both resolved from each elaborated
// instance.  The declaration defaults are intentionally too late to match.
// Independent signals make the [0:2] delay-zero and [2:2] delay-two matches
// individually observable with one match per antecedent attempt.
module cover_parameter_window_lower_override_checker #(
  parameter int LO = 7,
  parameter int HI = 9
) (
  input logic clk,
  input logic a,
  input logic b
);
  checked: cover property (@(posedge clk) a |-> ##[LO:HI] b);
endmodule

module sv_cover_parameter_window_lower_override;
  logic clk = 0;
  logic a_zero = 0;
  logic b_zero = 0;
  logic a_two = 0;
  logic b_two = 0;

  cover_parameter_window_lower_override_checker #(
    .LO(0),
    .HI(2)
  ) zero_to_two (
    .clk(clk),
    .a(a_zero),
    .b(b_zero)
  );

  cover_parameter_window_lower_override_checker #(
    .LO(2),
    .HI(2)
  ) exactly_two (
    .clk(clk),
    .a(a_two),
    .b(b_two)
  );

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    // Both attempts launch at t1. [0:2] matches immediately; [2:2] ignores
    // that tick and matches b_two exactly two clocks later at t3.
    a_zero = 1;
    b_zero = 1;
    a_two = 1;
    tick();
    a_zero = 0;
    b_zero = 0;
    a_two = 0;
    tick();
    b_two = 1;
    tick();
    b_two = 0;
    tick();

    if (zero_to_two._ivl_sva0_cnt0 !== 1) begin
      $display("FAILED: overridden [0:2] count was %0d, expected 1",
               zero_to_two._ivl_sva0_cnt0);
      $finish_and_return(1);
    end
    if (exactly_two._ivl_sva0_cnt0 !== 1) begin
      $display("FAILED: overridden [2:2] count was %0d, expected 1",
               exactly_two._ivl_sva0_cnt0);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish;
  end
endmodule
