// IEEE 1800-2017/2023 16.12.7 and 16.14.1: each failed attempt gets
// one else action, while vacuous passes and disabled attempts do not fail.
module literal_overlap_boundaries;
  logic clk = 0, start = 0, ready = 0, dis = 0;
  integer passes = 0, failures = 0, same_offset_failures = 0;

  checked: assert property (@(posedge clk) disable iff (dis)
      start |=> !ready[*3] ##1 ready)
    passes++;
  else failures++;

  // Two checks on the same attempt and sampled edge still get one verdict.
  same_offset: assert property (@(posedge clk) disable iff (dis)
      start |=> !ready ##0 (ready == 1'b0))
    ;
  else same_offset_failures++;

  task automatic tick(input logic s, r);
    start = s;
    ready = r;
    #5 clk = 1;
    #1 clk = 0;
  endtask

  task automatic check(input integer want_passes, want_failures);
    if (passes != want_passes || failures != want_failures) begin
      $display("FAILED: got %0d/%0d expected %0d/%0d",
          passes, failures, want_passes, want_failures);
      $finish_and_return(1);
    end
  endtask

  initial begin
    tick(0, 0); check(1, 0); // Vacuous pass.

    tick(1, 0);
    tick(0, 1); check(2, 1); // One early failure.

    tick(1, 0);
    tick(0, 0);
    tick(0, 0);
    tick(0, 0);
    tick(0, 1); check(7, 1); // One nonvacuous pass.

    tick(1, 0);
    tick(0, 1'bx); check(8, 2); // !X cannot match.
    tick(1, 0);
    tick(0, 1'bz); check(9, 3); // !Z cannot match.

    tick(1, 0);
    #1 dis = 1;
    #1 dis = 0;             // Async pulse cancels the live attempt.
    tick(0, 1); check(10, 3);

    tick(1, 0);
    start = 0; ready = 1;
    #5 clk = 1;
    dis <= 1;               // Observed disable wins at this clock.
    #1 clk = 0;
    check(10, 3);
    dis = 0;
    tick(0, 0); check(11, 3);

    if (same_offset_failures != 3)
      $fatal(1, "same-offset checks reported %0d/3 failures",
          same_offset_failures);

    $display("PASSED");
    $finish(0);
  end
endmodule
