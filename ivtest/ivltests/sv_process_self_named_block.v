// R4: `process::self()' inside a named begin/end must be the ENCLOSING
// process. IEEE 1800-2017 9.3.1 gives process status to fork...join
// branches, not to begin...end.
//
// A named block that owns an activation frame (one with automatic locals)
// is lowered as %fork/%join, and the runtime only marked a %fork child as
// sharing its parent's logical process when the target was a task scope.
// So process::self() inside such a block returned a different handle from
// the enclosing process -- silently, with no diagnostic, and including for
// the block's own declaration initializers, which run in the parent thread
// while the body runs in the child. Any code that captures self() in one
// and compares in the other saw two unrelated processes.
//
// The test pins BOTH directions at once, because fixing one by making every
// %fork child share its parent would destroy the other: a fork branch must
// still be its own process.
module main;

  process enclosing;
  process br1, br2;
  process init_captured, body_captured;
  int shares_auto = 0, shares_plain = 0;

  task automatic tk;
    begin
      automatic process q = process::self();
      process r;
      r = process::self();
      init_captured = q;
      body_captured = r;
    end
  endtask

  initial begin
    enclosing = process::self();

    // A named block with an automatic local: not a process.
    begin : auto_local
      automatic int z = 5;
      if (process::self() == enclosing) shares_auto = z;
    end

    // A named block without one: also not a process.
    begin : plain_local
      int y;
      y = 7;
      if (process::self() == enclosing) shares_plain = y;
    end

    // Fork branches: each IS its own process, distinct from the enclosing
    // one and from each other.
    fork
      begin : b1 automatic int a1 = 1; br1 = process::self(); end
      begin : b2 automatic int a2 = 2; br2 = process::self(); end
    join

    tk();

    if (shares_auto != 5)
      $display("FAILED -- process::self() in a named block with an automatic local is not the enclosing process");
    else if (shares_plain != 7)
      $display("FAILED -- process::self() in a plain named block is not the enclosing process");
    else if (br1 == enclosing || br2 == enclosing)
      $display("FAILED -- a fork branch reported the enclosing process; fork...join branches ARE their own processes");
    else if (br1 == br2)
      $display("FAILED -- two fork branches reported the same process");
    else if (init_captured != body_captured)
      $display("FAILED -- a declaration initializer captured a different process from the block body");
    else
      $display("PASSED");

    $finish(0);
  end

endmodule
