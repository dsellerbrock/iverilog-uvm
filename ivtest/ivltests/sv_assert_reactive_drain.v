// R2, termination half: deferring an assertion ACTION to the Reactive
// region (IEEE 1800-2017 4.4.2.5) must not lose a verdict at the end of
// simulation. The first attempt at the deferral was reverted because it
// did exactly that, in two distinct ways -- both pinned here.
//
//  1. $finish in the ACTIVE region of a time slot. The remaining regions
//     of that slot still run, so an action deferred out of the Observed
//     region of the same slot reports: `ACTION at 25' must follow
//     `FINISH at 25'.
//
//  2. A `final'-block action. An unfulfilled strong obligation (16.12.2)
//     is reported from a synthesized final block, where no Reactive
//     region is reachable at all. `%wait/reactive' falls through and runs
//     the action inline there, so the ERROR is still reported.
//
// Without the fall-through the strong-property ERROR disappears entirely
// and the t=25 action is lost; with the action left inline in Observed
// the two t=25 lines come out in the other order.
module main;

  reg clk = 0;
  reg b   = 0;   // always false: every edge of a_now fails
  reg req = 0;
  reg ack = 0;   // never asserted: the strong obligation never completes

  always #5 clk = ~clk;

  a_now: assert property (@(posedge clk) b)
    else $display("ACTION at %0t", $time);

  a_strong: assert property (@(posedge clk) req |-> strong(##[1:$] ack));

  initial begin
    @(negedge clk) req = 1;   // t=10: seen by the t=15 attempt
    @(negedge clk) req = 0;   // t=20
    @(posedge clk);           // t=25
    $display("FINISH at %0t", $time);
    $finish(0);
  end

endmodule
