// IEEE 1800-2017 16.14.6: an assertion reports through the action block
// the user wrote. 16.12.2: a `strong' sequence that never completes is a
// failure, and the only moment that can be decided is the end of
// simulation.
//
// Those two met badly. The unbounded-sequence lowering handed the
// per-cycle dispatch the user's `else' and gave the end-of-simulation
// report a canned `$error' instead, with a comment claiming the else
// "never fires" for such a property. So
//
//     assert property (@(posedge clk) a |-> strong(##[1:$] b)) else miss++;
//
// with `b' never rising printed an $error nobody asked for and left
// `miss' at 0 -- a real failure, announced through a channel the user
// did not write and could not intercept. A test counting its own
// failures saw none.
//
// The claim was also wrong on its own terms: a cyclic strong sequence
// CAN fail during the run, as the second case below does. Both sites
// need the statement, so the end-of-simulation site now gets a copy of
// it (sva_clone_stmt_).
//
// The end-of-simulation report necessarily runs after $finish, in the
// final region, so this test reads its counters from a `final' block.
// Reading them at $finish would see the run-time failures only -- which
// is exactly what the `at $finish' line below pins.

module main;

  logic clk = 0, a = 0, b = 0;

  int strong_else  = 0;    // unbounded: can only fail at end of simulation
  int early_else   = 0;    // cyclic strong, but fails during the run
  int weak_else    = 0;    // control: no strong, same shape
  int plain_else   = 0;    // control: an ordinary bounded failure
  int msg_else     = 0;    // an action block with arguments and a block
  int at_finish    = -1;

  int fails = 0;

  always #5 clk = ~clk;

  // 1. never completes: the end of simulation is the only verdict
  s1: assert property (@(posedge clk) a |-> strong(##[1:$] b))
         else strong_else++;

  // 2. cyclic and strong, but `b' is low at the next tick so the
  //    attempt is dead during the run. This is the case the old comment
  //    said could not happen.
  s2: assert property (@(posedge clk) a |-> strong(b ##[1:$] b))
         else early_else++;

  // 3. control: the same shape without `strong'
  s3: assert property (@(posedge clk) a |-> (b ##[1:$] b))
         else weak_else++;

  // 4. control: an ordinary bounded assertion
  s4: assert property (@(posedge clk) a |-> ##1 b)
         else plain_else++;

  // 5. an action block that is not a bare increment: the copy has to
  //    reproduce a begin/end, a call with arguments, and an if.
  s5: assert property (@(posedge clk) a |-> strong(##[1:$] b))
         else begin
           msg_else = msg_else + 1;
           if (msg_else > 100) $display("unreachable");
         end

  initial begin
    @(negedge clk) a = 1;
    @(negedge clk) a = 0; b = 0;
    repeat (6) @(negedge clk);
    at_finish = strong_else;
    $finish(0);
  end

  final begin
    // The end-of-simulation failures land here, after $finish.
    if (at_finish !== 0) begin
      fails++;
      $display("FAILED -- the unbounded strong failure was reported during the run: %0d",
               at_finish);
    end
    if (strong_else == 0) begin
      fails++;
      $display("FAILED -- a strong sequence that never completed never ran the user's else");
    end
    if (msg_else == 0) begin
      fails++;
      $display("FAILED -- a begin/end action block was not reproduced for the end-of-simulation failure");
    end
    if (early_else == 0) begin
      fails++;
      $display("FAILED -- a cyclic strong sequence stopped reporting its run-time failure");
    end
    if (weak_else == 0) begin
      fails++;
      $display("FAILED -- the weak control stopped reporting");
    end
    if (plain_else == 0) begin
      fails++;
      $display("FAILED -- the bounded control stopped reporting");
    end

    if (fails == 0) $display("PASSED");
    else            $display("FAILED (%0d)", fails);
  end

endmodule
