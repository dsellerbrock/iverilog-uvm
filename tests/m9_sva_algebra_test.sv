// M9-2 pass 1: sequence algebra on the token-pipeline engine.
//
//   1. Consecutive repetition e[*N] (desugars to e ##1 e ... e).
//   2. Final-position range repetition e[*m:n] (match-equivalent to
//      e[*m] there).
//   3. Sequence antecedents: (a ##1 b) |-> c via history-AND match
//      detection, overlap-correct.
//   4. not(seq): fails exactly when the sequence matches.
//   5. first_match(seq): transparent in match-existence positions.
//   6. Pass actions: `assert property (P) pass_stmt;` executes on
//      each match.
//   7. Regression probe: plain bit-selects inside assertion booleans
//      still parse (v[1] vs the new [* rules).

`timescale 1ns/1ns

module m9_sva_algebra_test;
  logic clk = 0;
  logic r1 = 0;
  logic a3 = 0, b3 = 0, c3 = 0;
  logic n4 = 0, m4 = 0;
  logic a5 = 0, b5 = 0;
  logic p6 = 0;
  logic [3:0] v7 = 4'b0010;
  int e1 = 0, e2 = 0, e3 = 0, e4 = 0, e5 = 0, e7 = 0;
  int pass6 = 0;
  int errors = 0;

  always #5 clk = ~clk;   // posedges at 5, 15, 25, ...

  task check(input bit ok, input string what);
    if (!ok) begin
      errors++;
      $display("FAILED: %s", what);
    end
  endtask

  // 1: r1 high implies r1 stays high 3 cycles (r1[*3] from this one).
  assert property (@(posedge clk) r1 |-> r1[*3]) else e1++;

  // 2: final range repetition — needs the first 2 of up to 4.
  assert property (@(posedge clk) r1 |-> r1[*2:4]) else e2++;

  // 3: sequence antecedent.
  assert property (@(posedge clk) (a3 ##1 b3) |-> c3) else e3++;

  // 4: not — fail exactly when n4 ##1 m4 matches.
  assert property (@(posedge clk) not (n4 ##1 m4)) else e4++;

  // 5: first_match is transparent.
  assert property (@(posedge clk) a5 |-> first_match(##1 b5)) else e5++;

  // 6: pass action fires per match.
  assert property (@(posedge clk) p6 |-> 1'b1) pass6++;

  // 7: bit-select in an assertion boolean.
  assert property (@(posedge clk) v7[1] |-> !v7[0]) else e7++;

  initial begin
    // ---- 1+2: hold r1 high 3 cycles: t=5,15,25 all high ----
    r1 = 1;
    repeat (3) begin @(posedge clk); #1; end   // t=5,15,25
    r1 = 0;
    @(posedge clk); #1;                        // t=35 (r1 low)
    check(e1 == 1 && e2 == 1,
          "1/2: attempts at t=15,t=25 fail when r1 drops; t=5 attempt passed");
    // (attempt at t=5: r1 high 5,15,25 => [*3] pass; attempts at
    //  t=15/t=25 run off the drop: [*3] fails once (t=15 chain sees
    //  low at 35 -> e1), [*2] fails once for t=25 -> e2.)

    // ---- 3: antecedent (a3 ##1 b3): a3 at t=45, b3 at t=55, c3 must
    //         hold at t=55 (overlapped). First pass, then fail. ----
    a3 = 1;
    @(posedge clk); #1;      // t=45: a3 sampled
    a3 = 0; b3 = 1; c3 = 1;
    @(posedge clk); #1;      // t=55: b3&&c3 -> match, consequent ok
    b3 = 0; c3 = 0;
    check(e3 == 0, "3: sequence antecedent match with consequent passes");
    a3 = 1;
    @(posedge clk); #1;      // t=65
    a3 = 0; b3 = 1; c3 = 0;  // antecedent completes at t=75, c3 low
    @(posedge clk); #1;
    b3 = 0;
    check(e3 == 1, "3: sequence antecedent failure detected");

    // ---- 4: not(n4 ##1 m4) ----
    n4 = 1;
    @(posedge clk); #1;      // t=85: n4 sampled
    n4 = 0; m4 = 0;
    @(posedge clk); #1;      // t=95: m4 low -> no match -> no fail
    check(e4 == 0, "4: not() quiet without a match");
    n4 = 1;
    @(posedge clk); #1;      // t=105
    n4 = 0; m4 = 1;
    @(posedge clk); #1;      // t=115: match -> fail
    m4 = 0;
    check(e4 == 1, "4: not() fails exactly on the match");

    // ---- 5: first_match transparency ----
    a5 = 1;
    @(posedge clk); #1;      // t=125
    a5 = 0; b5 = 1;
    @(posedge clk); #1;      // t=135: b5 -> pass
    b5 = 0;
    check(e5 == 0, "5: first_match passes");
    a5 = 1;
    @(posedge clk); #1;      // t=145
    a5 = 0;                  // b5 low at t=155 -> fail
    @(posedge clk); #1;
    check(e5 == 1, "5: first_match failure detected");

    // ---- 6: pass action ----
    p6 = 1;
    @(posedge clk); #1;      // t=165
    @(posedge clk); #1;      // t=175
    p6 = 0;
    check(pass6 == 2, "6: pass action fired once per match");

    // ---- 7: selects fine; v7=4'b0010 -> v7[1]=1, v7[0]=0: holds ----
    @(posedge clk); #1;
    check(e7 == 0, "7: bit-selects in assertion booleans work");

    if (errors == 0)
      $display("PASSED: all m9 sva algebra checks");
    else
      $display("FAILED: %0d m9 sva algebra checks", errors);
    $finish(0);
  end
endmodule
