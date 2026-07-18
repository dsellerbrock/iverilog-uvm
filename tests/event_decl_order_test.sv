// Regression: an `event` declaration placed AFTER another declaration in a
// task/function/block body was rejected as "syntax error / Malformed
// statement" (automatic_task, always_comb/ff/latch_warn). Mechanism: a
// leading variable declaration reduces out of the declaration section (the
// empty-K_const_opt vs empty-declaration-list conflict resolves toward the
// statement path) and parses as an inline statement declaration — but
// statement context had no event-declaration rule, so a subsequent
// `event e;` exploded. statement_item now accepts an event declaration
// (IEEE 1800-2017 6.18 allows declarations intermixed with statements),
// registered identically to the block_item_decl path.
module top;

  // event after a variable decl in a task, then actually used.
  task automatic t1(output int done_at);
    reg [7:0] scratch;
    event ping;                 // was: Malformed statement
    scratch = 8'h1;
    fork
      begin #5 -> ping; end
      begin @(ping) done_at = 5; end
    join
  endtask

  // event after a memory decl (the automatic_task shape).
  task t2(output bit ok);
    reg [7:0] array [3:0];
    event step;                 // was: Malformed statement
    begin
      array[0] = 8'h2a;
      fork
        begin #1 -> step; end
        begin @(step) ok = (array[0] === 8'h2a); end
      join
    end
  endtask

  // event between declarations inside a plain begin/end block.
  initial begin
    int before_evt;
    event mid;
    reg [3:0] after_evt;
    int done;
    bit ok2;

    before_evt = 1; after_evt = 4'h7;
    t1(done);
    t2(ok2);
    fork
      begin #1 -> mid; end
      begin @(mid) before_evt = 2; end
    join
    if (done === 5 && ok2 && before_evt === 2 && after_evt === 4'h7)
      $display("PASS: event declarations after other declarations");
    else
      $display("FAIL: done=%0d ok2=%b before=%0d after=%h", done, ok2, before_evt, after_evt);
    $finish;
  end
endmodule
