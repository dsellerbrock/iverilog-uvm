// C5-2 (CL1-001): the natural overlapped-implication idiom
//   req |-> ##[1:2] a[->1] ##1 c
// (IEEE 1800-2017 16.9.2/16.9.4/16.12.7) -- pre-fix a compile-time
// sorry telling the user to enable the automaton engine that had
// already declined it. Pass counting is pinned; note a weak
// implication whose consequent holds a still-waiting goto can never
// definitively FAIL in finite time (a match stays possible), so the
// discriminating negative here is "no spurious pass", with fail=0
// throughout.
module impl_window_goto_nfa_only;
  logic clk = 0, req = 0, a = 0, c = 0;
  logic req2 = 0, b2 = 0, c2 = 0;
  int pass_n = 0, fail_n = 0;
  int pass2_n = 0, fail2_n = 0;
  always #5 clk = ~clk;

  ig: assert property (@(posedge clk) req |-> ##[1:2] a[->1] ##1 c)
        pass_n++;
        else fail_n++;

  // Overlapped consequent starting with a goto: the [->2] count
  // begins ##0-fused ON the antecedent tick itself.
  ig2: assert property (@(posedge clk) req2 |-> b2[->2] ##1 c2)
        pass2_n++;
        else fail2_n++;

  initial begin
    // must-pass: req@T, a@T+1 (window split +1 sees it immediately),
    // c@T+2 one tick after the goto endpoint.       pass 0->1
    @(negedge clk) req = 1;
    @(negedge clk) begin req = 0; a = 1; end
    @(negedge clk) begin a = 0; c = 1; end
    @(negedge clk) c = 0;
    repeat (2) @(negedge clk);
    // goto-waits-past-window pass: req@T', a@T'+4, c@T'+5.
    //                                                pass 1->2
    @(negedge clk) req = 1;
    @(negedge clk) req = 0;
    repeat (2) @(negedge clk);
    @(negedge clk) a = 1;
    @(negedge clk) begin a = 0; c = 1; end
    @(negedge clk) c = 0;
    repeat (2) @(negedge clk);
    // no-pass control: req with NO subsequent a -- the consequent
    // waits forever: no pass, and (weak semantics) no fail either.
    @(negedge clk) req = 1;
    @(negedge clk) req = 0;
    repeat (3) @(negedge clk);

    // ig2 must-pass: b2 on the req2 tick (fused occurrence 1) and at
    // +2 (occurrence 2), c2 at +3.                  pass2 0->1
    @(negedge clk) begin req2 = 1; b2 = 1; end
    @(negedge clk) begin req2 = 0; b2 = 0; end
    @(negedge clk) b2 = 1;
    @(negedge clk) begin b2 = 0; c2 = 1; end
    @(negedge clk) c2 = 0;
    repeat (2) @(negedge clk);
    // ig2 no-pass control (LAST: nothing later can complete it):
    // b2 once at +1, never a second time -> waits forever.
    @(negedge clk) req2 = 1;
    @(negedge clk) begin req2 = 0; b2 = 1; end
    @(negedge clk) b2 = 0;
    repeat (3) @(negedge clk);
    $display("ig pass=%0d (exp 2) fail=%0d (exp 0)", pass_n, fail_n);
    $display("ig2 pass=%0d (exp 1) fail=%0d (exp 0)", pass2_n, fail2_n);
    $finish(0);
  end
endmodule
