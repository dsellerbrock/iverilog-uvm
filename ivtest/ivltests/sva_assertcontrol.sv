// IEEE 1800-2023 20.11 (1800-2017 20.12): $assertcontrol and the assertion
// action control tasks. Every action block counts its executions; the
// counts are printed at the end and compared with the gold file.
//
// Clock edges are at 5, 15, ..., 75. Controls run between edges.
//
// Action controls are read when the action is dispatched; an attempt that
// is already in flight is not grandfathered, in either direction (user
// ruling 2026-11-10 on 20.11 "An assertion that is already executing,
// including execution of the pass or fail action, is not affected").
// The `in-flight' line is the only gold line that depends on this ruling.
module sva_assertcontrol;
  // The 20.11 example's names for the control arguments.
  let LOCK = 1;
  let UNLOCK = 2;
  let ON = 3;
  let OFF = 4;
  let PASSOFF = 7;
  let FAILON = 8;
  let FAILOFF = 9;
  let CONCURRENT = 1;
  let S_IMMEDIATE = 2;
  let D_OBSERVED = 4;
  let D_FINAL = 8;
  let ALL_ASSERTS = 31;
  let ASSERT = 1;
  let COVER = 2;
  let ALL_DIRECTIVES = 7;

  logic clk = 0;
  always #5 clk = ~clk;

  logic f = 0;          // always false: every check fails
  logic t = 1;          // always true
  logic h = 1;          // 1 at edges 5, 25, 45, 65; 0 at 15, 35, 55, 75
  logic s = 0;          // 1 only at edge 15
  always #10 h = ~h;
  initial begin #10 s = 1; #10 s = 0; end

  int f_a1, f_a2, f_a3, f_ia, c_c4, p_a4, p_a5, p_a6, p_a6b, f_k1, f_k2;
  int c_ic9;

  // A: fail action off, then on again through empty positional arguments.
  a1: assert property (@(posedge clk) f) else f_a1++;
  // B: a lock set at time 0, before or after a1's registration.
  a2: assert property (@(posedge clk) f) else f_a2++;
  // C: assertion_type mask: only simple immediate assertions.
  a3: assert property (@(posedge clk) f) else f_a3++;
  always @(posedge clk) begin
    ia: assert (f) else f_ia++;
  end
  // D: directive_type mask: only cover directives.
  c4: cover property (@(posedge clk) t) c_c4++;
  a4: assert property (@(posedge clk) t) p_a4++;
  // E: vacuous and nonvacuous pass actions.
  a5: assert property (@(posedge clk) h |-> t) p_a5++;
  // F: an attempt in flight while its pass action control changes.
  a6: assert property (@(posedge clk) s |-> ##2 t) p_a6++;
  a6b: assert property (@(posedge clk) s |-> ##2 t) p_a6b++;
  // G: deferred immediate assertions, by assertion_type.
  always @(posedge clk) begin
    assert #0 (f) else $display("observed deferred fail at %0t", $time);
    assert final (f) else $display("final deferred fail at %0t", $time);
  end
  // H: a labeled immediate cover selected by its label.
  always @(posedge clk) begin
    ic9: cover (t) c_ic9++;
  end
  // I: issue #863's list form, a concurrent and a simple immediate assertion.
  k1: assert property (@(posedge clk) f) else f_k1++;
  always @(posedge clk) begin
    k2: assert (f) else f_k2++;
  end

  initial begin
    $assertcontrol(LOCK, ALL_ASSERTS, ALL_DIRECTIVES, 0, a2);
    $assertoff(0, a2);                          // locked: no effect
    $assertvacuousoff(0, a6);
    $assertpassoff(0, a6b);
    #20;
    $assertcontrol(OFF, S_IMMEDIATE, ALL_DIRECTIVES, 0, ia, a3); // ia only
    $assertvacuousoff(0, a5);
    $assertpassoff(0, a6);                      // a6's attempt from 15 passes at 35
    $assertnonvacuouson(0, a6b);                // a6b's attempt from 15 passes at 35
    $assertcontrol(FAILOFF, D_OBSERVED);
    #10;
    $assertcontrol(FAILOFF, CONCURRENT, ASSERT, 0, a1);
    $assertcontrol(PASSOFF, CONCURRENT, COVER); // c4 stops, a4 does not
    $assertpassoff(0, ic9);
    $assertcontrol(9, 15, 7, 0, k1, k2);
    #10;
    $assertcontrol(UNLOCK, ALL_ASSERTS, ALL_DIRECTIVES, 0, a2);
    $assertoff(0, a2);
    $assertpassoff(0, a5);
    $assertcontrol(FAILOFF, D_FINAL);
    #20;
    $assertcontrol(FAILON, , , 0, a1);          // defaults 255, 7
    $assertnonvacuouson(0, a5);
    $assertcontrol(FAILON, D_OBSERVED | D_FINAL);
    #20;
    $display("a1 fail actions: %0d", f_a1);
    $display("a2 fail actions: %0d", f_a2);
    $display("a3 fail actions: %0d, ia fail actions: %0d", f_a3, f_ia);
    $display("c4 cover actions: %0d, a4 pass actions: %0d", c_c4, p_a4);
    $display("a5 pass actions: %0d", p_a5);
    $display("in-flight: a6 pass actions: %0d, a6b pass actions: %0d",
             p_a6, p_a6b);
    $display("ic9 cover actions: %0d", c_ic9);
    $display("k1 fail actions: %0d, k2 fail actions: %0d", f_k1, f_k2);
    $finish;
  end
endmodule
