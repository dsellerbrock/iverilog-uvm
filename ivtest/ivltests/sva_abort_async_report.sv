// IEEE 1800-2023 16.12.14 / 16.14.8(ab, ac): when an asynchronous abort is
// reported. The condition is checked in every time step, but a
// discrete-event checker sees that it held only at the next clock tick or
// at its next change, so the verdict comes at whichever is first (user
// ruling 2026-11-06). The VPI module logs P<time> / V<time> / F<time> for
// nonvacuous success, vacuous success and failure of each assertion (the
// fail actions are empty; the failure callback still fires).
//   y high 17..19 (between ticks 15 and 25): reported at 19
//   y high 47..58 (holds at tick 55):        reported at 55
//   y 0 -> 1 -> 0 at 67 (one time step):     no abort
// An aborted attempt is vacuous, so q3's `or' passes vacuously at 25 and 55
// although its reject_on operand failed.
module sva_abort_async_report;
  bit clk = 0;
  bit a, b, c, d, e, y;
  //               tick 0 1 2 3 4 5 6 7 8 9
  bit va[10] = '{1,0,0,1,0,0,1,0,0,0}, vb[10] = '{0,1,0,0,1,0,0,1,0,0},
      vc[10] = '{0,0,1,0,0,1,0,0,1,0}, vd[10] = '{1,0,0,0,0,0,0,0,0,0};

  always #5 clk = ~clk;   // tick k at 10k+5

  q0: assert property (@(posedge clk) accept_on(y) (a ##1 b ##1 c)) else ;
  q1: assert property (@(posedge clk) reject_on(y) (a |=> b ##1 c)) else ;
  q2: assert property (@(posedge clk) (reject_on(y) (a |=> b ##1 c)) and (d |-> ##2 d)) else ;
  q3: assert property (@(posedge clk) (reject_on(y) (a |=> b ##1 c)) or (d ##2 e |-> 0)) else ;

  initial begin
    $vac_setup;
    {a, b, c, d, e} = {va[0], vb[0], vc[0], vd[0], 1'b0};
    for (int k = 1; k < 10; k++)
      @(negedge clk) {a, b, c, d} = {va[k], vb[k], vc[k], vd[k]};
    @(posedge clk);
    #1 $vac_dump;
    $finish;
  end
  initial begin
    #17 y = 1; #2 y = 0;
    #28 y = 1; #11 y = 0;
    #9 y = 1; y = 0;
  end
endmodule
