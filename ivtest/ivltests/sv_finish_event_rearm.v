// $finish must drain work that is already scheduled in the current time
// slot without allowing an event-controlled process to re-arm and spawn an
// unbounded series of new evaluations.  The two combinational procedures
// deliberately make real 0->1 intermediate transitions once enable is set;
// without the post-finish event-wake guard they keep waking each other after
// the initial block has called $finish.
module sv_finish_event_rearm;
  logic enable = 1'b0;
  logic a = 1'b0;
  logic b = 1'b0;
  integer a_runs = 0;
  integer b_runs = 0;

  always_comb begin
    a_runs = a_runs + 1;
    a = 1'b0;
    if (enable)
      a = 1'b1;
    if (enable && b)
      a = 1'b1;
  end

  always_comb begin
    b_runs = b_runs + 1;
    b = 1'b0;
    if (enable)
      b = 1'b1;
    if (enable && a)
      b = 1'b1;
  end

  initial begin
    #1;
    enable = 1'b1;
    $finish(0);
  end

  final begin
    if (a !== 1'b1 || b !== 1'b1 || a_runs < 2 || b_runs < 2)
      $display("FAILED: a=%b b=%b a_runs=%0d b_runs=%0d",
               a, b, a_runs, b_runs);
    else
      $display("PASSED");
  end
endmodule
