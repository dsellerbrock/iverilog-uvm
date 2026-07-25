// M9-7: variable-length CONSEQUENT operands on a multiclocked implication
// (IEEE 1800-2017 16.13.3). Both forms below used to be a loud sorry that
// dropped the assertion.
//
// A property is satisfied by the EARLIEST match of its consequent, which is
// what makes these tractable without per-obligation automaton state:
//
//   - `b[*m:n]' collapses to `b[*m]'. The parser already does this, leaving
//     the n-m on the step as `rep_tail'; the consequent may simply drop it.
//     An ANTECEDENT may not -- each extra match there is its own obligation.
//
//   - a trailing `##[m:n]' becomes a window of ticks the obligation may be
//     discharged on. At most one obligation enters the c2 pipeline per tick,
//     so a pipeline stage index IS an obligation age and identifies it
//     uniquely: discharging one age cannot disturb another in flight. Only
//     trailing, because a mid-chain window branches.
//
// c1 posedges at 10,30,50,...; c2 posedges at 15,35,55,75,95 -- each c2 tick
// strictly after the c1 tick that hands off to it.
module main;

  reg c1 = 0, c2 = 0;
  reg a = 0, b = 0;
  reg a_all = 1, b_all = 1;

  int f_rep = 0, f_plain = 0;        // b[*1:3] vs plain b
  int f_narrow = 0, f_wide = 0;      // ##[1:3] vs ##[1:4], same stimulus
  int f_overlap = 0;                 // overlapping obligations in a window

  // A repetition consequent must be indistinguishable from its shortest form.
  rp: assert property (@(posedge c1) a_all |=> @(posedge c2) b[*1:3]) else f_rep++;
  pl: assert property (@(posedge c1) a_all |=> @(posedge c2) b)       else f_plain++;

  // One obligation (a is high only at c1@10), handed off at c2@15 = age 0,
  // so [1:3] covers c2@35/55/75 and [1:4] additionally covers c2@95. b rises
  // at t=80, strictly between c2@75 and c2@95 so no edge races it: the
  // narrow window must expire unmatched and the wide one must catch it.
  // Nothing but an exact window boundary produces that pair of answers.
  nw: assert property (@(posedge c1) a |=> @(posedge c2) 1'b1 ##[1:3] b) else f_narrow++;
  wd: assert property (@(posedge c1) a |=> @(posedge c2) 1'b1 ##[1:4] b) else f_wide++;

  // Every c1 tick creates an obligation, so several are alive in the window
  // at once. All match: a discharge at one age must not disturb the others.
  ov: assert property (@(posedge c1) a_all |=> @(posedge c2) 1'b1 ##[1:3] b_all) else f_overlap++;

  always #10 c1 = ~c1;
  initial begin #5 forever #10 c2 = ~c2; end

  initial begin
    a = 1; #15 a = 0;          // t=15: only c1@10 saw a
    #65 b = 1;                 // t=80: strictly between c2@75 and c2@95
    #75;                       // t=155

    if (f_plain == 0)
      $display("FAILED -- the plain-consequent control never fired (%0d); the test itself is broken",
               f_plain);
    else if (f_rep != f_plain)
      $display("FAILED -- b[*1:3]=%0d plain b=%0d; a repetition consequent is not matching at its earliest opportunity",
               f_rep, f_plain);
    else if (f_narrow != 1)
      $display("FAILED -- the ##[1:3] window saw %0d failures, expected 1; b arrives at age 4, outside it",
               f_narrow);
    else if (f_wide != 0)
      $display("FAILED -- the ##[1:4] window saw %0d failures, expected 0; b arrives at age 4, inside it",
               f_wide);
    else if (f_overlap != 0)
      $display("FAILED -- overlapping obligations in a window produced %0d failures; discharging one age disturbed another",
               f_overlap);
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
