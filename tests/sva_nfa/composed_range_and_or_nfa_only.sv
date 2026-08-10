// IEEE 1800-2017 16.9.5/16.9.7: ranged operands of sequence `and'/`or'
// remain composable through ##0.  The large [1:6]/[1:9] `and' is the
// exact state-grid shape from sv-tests 16.7--sequence-and-range-uvm: the
// product contains many Cartesian pairs that no common start tick can ever
// reach.  The NFA must discard those pairs without changing the language.
//
// The counters pin later-end timing, both `or' branches, and the convention
// that one successful attempt counts once even when several endpoint pairs
// reach the same ##0 continuation.  The early/late controls are deliberately
// one tick wrong: accepting either would change ##0 or `and' endpoint
// semantics, so their required count is exactly zero.
module composed_range_and_or_nfa_only;
  logic clk = 0;
  logic a1=0, b1=0, c1=0, d1=0;
  logic a2=0, b2=0, c2=0, d2=0;
  logic a3=0, b3=0, c3=0, d3=0;
  logic a4=0, b4=0, c4=0, d4=0;
  logic a5=0, b5=0, c5=0, d5=0;
  logic a6=0, b6=0, c6=0, d6=0;
  logic a7=0, b7=0, c7=0, d7=0;
  always #5 clk = ~clk;

  ca_ok: cover property (@(posedge clk)
      ((a1 ##[1:6] b1) and (a1 ##[1:9] c1)) ##0 d1);
  ca_early: cover property (@(posedge clk)
      ((a2 ##[1:6] b2) and (a2 ##[1:9] c2)) ##0 d2);
  ca_late: cover property (@(posedge clk)
      ((a3 ##[1:6] b3) and (a3 ##[1:9] c3)) ##0 d3);
  ca_multi: cover property (@(posedge clk)
      ((a4 ##[1:6] b4) and (a4 ##[1:9] c4)) ##0 d4);
  co_left: cover property (@(posedge clk)
      ((a5 ##[1:6] b5) or (a5 ##[1:9] c5)) ##0 d5);
  co_right: cover property (@(posedge clk)
      ((a6 ##[1:6] b6) or (a6 ##[1:9] c6)) ##0 d6);
  co_late: cover property (@(posedge clk)
      ((a7 ##[1:6] b7) or (a7 ##[1:9] c7)) ##0 d7);

  initial begin
    // All seven attempts anchor at offset 0.
    @(negedge clk) begin
      a1=1; a2=1; a3=1; a4=1; a5=1; a6=1; a7=1;
    end

    // +1: first of two possible left endpoints for ca_multi.
    @(negedge clk) begin
      a1=0; a2=0; a3=0; a4=0; a5=0; a6=0; a7=0;
      b4=1;
    end

    // +2: ordinary early endpoints.  d2 is intentionally true only
    // here; ca_early's right operand does not finish until +8.
    @(negedge clk) begin
      b4=0; b1=1; b2=1; b3=1; c4=1; d2=1;
    end

    // +3: second possible left endpoint for ca_multi.
    @(negedge clk) begin
      b1=0; b2=0; b3=0; c4=0; d2=0; b4=1;
    end

    // +4: second right endpoint and the fused continuation.  Several
    // left/right endpoint pairs complete here, but this is one attempt.
    @(negedge clk) begin
      b4=0; c4=1; d4=1;
    end

    // +5: prove the left branch of the ranged `or'.
    @(negedge clk) begin
      c4=0; d4=0; b5=1; d5=1;
    end
    @(negedge clk) begin
      b5=0; d5=0;
    end

    // +7: quiet tick.
    @(negedge clk);

    // +8: later `and' endpoints and right-branch `or' endpoints.
    // d1/d6 are correctly fused.  d3/d7 remain false until +9.
    @(negedge clk) begin
      c1=1; c2=1; c3=1; d1=1;
      c6=1; d6=1; c7=1;
    end

    // +9: one tick too late for ca_late and co_late.
    @(negedge clk) begin
      c1=0; c2=0; c3=0; d1=0; c6=0; d6=0; c7=0;
      d3=1; d7=1;
    end
    @(negedge clk) begin
      d3=0; d7=0;
    end

    repeat (2) @(negedge clk);
    $display("and ok=%0d early=%0d late=%0d multi=%0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0,
             _ivl_sva2_cnt0, _ivl_sva3_cnt0);
    $display("or left=%0d right=%0d late=%0d",
             _ivl_sva4_cnt0, _ivl_sva5_cnt0, _ivl_sva6_cnt0);
    $finish(0);
  end
endmodule
