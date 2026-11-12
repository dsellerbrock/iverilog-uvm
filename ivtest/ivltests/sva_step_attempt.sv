// IEEE 1800-2023 39.4.2 / 39.5.2: step callbacks are per attempt and off
// until vpiAssertionEnableStep names the attempt's start time, issued
// before the attempt starts or in its own cbAssertionStart callback (SVA
// Q7, 2026-11-12). One step is one clock tick of one attempt; it carries
// the booleans checked on that tick (a failing step ends with the one that
// failed) and the state ids (0 origin, 1 accepting).
//
// posedges at 5,15,25,35,45. a=1 sampled at 5 and 25, b at 15 and 35,
// c never.
//   seq:  a ##1 b ##1 c   steps enabled from START for attempts 5 and 25,
//         ahead of time for 45 (never runs: a=0 there fails at once),
//         ahead of time for 35 then disabled again; a late enable for 15
//         has no effect.
//   win:  a ##[1:2] b     attempt 25 enabled in START; matches at 35.
//   imp:  a |-> ##1 c     attempts 5 (fails at 15) and 15 (vacuous).
//   off:  a ##1 b         callbacks registered, stepping never enabled.
//   rep:  a ##1 b[*1:2] ##1 c   automaton checker, attempt 25.
//   rim:  ranged antecedent with fan-out: EnableStep refuses (sorry, 0).
//   aim, nxt, nim, exl, exn: every attempt, from START, through t=25:
//         antecedent ages, |=>, an automaton implication's vacuous end,
//         and compound booleans.
module sva_step_attempt;
  bit clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  seq: assert property (@(posedge clk) a ##1 b ##1 c) else ;
  win: assert property (@(posedge clk) a ##[1:2] b) else ;
  imp: assert property (@(posedge clk) a |-> ##1 c) else ;
  off: assert property (@(posedge clk) a ##1 b) else ;
  rep: assert property (@(posedge clk) a ##1 b[*1:2] ##1 c) else ;
  rim: assert property (@(posedge clk) a ##[1:2] b |-> c) else ;
  aim: assert property (@(posedge clk) a ##1 b |-> c) else ;
  nxt: assert property (@(posedge clk) a |=> b) else ;
  nim: assert property (@(posedge clk) a |-> b[*1:2] ##1 c) else ;
  exl: assert property (@(posedge clk) (a || b) ##1 $fell(a) ##1 !c) else ;
  exn: assert property (@(posedge clk) (a || b) ##1 b[*1:2] ##1 (c == 0)) else ;

  initial begin
    #1 $step_setup;
    a = 1;
    #10 a = 0; b = 1;
    #5 $step_late;
    #5 a = 1; b = 0;
    #10 a = 0; b = 1;
    #10 b = 0;
    #10 $finish(0);
  end
endmodule
