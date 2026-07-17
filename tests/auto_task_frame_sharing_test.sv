// Regression: automatic-variable storage must follow the single-task-frame
// model. A named begin block inside an automatic task does not get its own
// activation frame; its locals live in the frame allocated for the task
// call. Under the retired per-block-frame model, a blocking fork...join
// inside such a block corrupted parent-scope reads: when one branch ended
// before a sibling branch read a parent-scope automatic local, the shared
// parent context was dropped from the context chain the live sibling read
// through, and the read returned the element default (x).
//
// The failing shape (from ivtest automatic_events2 root-cause analysis):
// branch A ends at #10, branch B reads the named-block local `acc` at #30.
module top;

  task automatic w(input byte id, output byte r);
    begin: body
      reg [7:0] acc;
      acc = id;
      fork
        begin #10 ; end          // branch A ends early
        begin #30 r = acc; end   // branch B reads parent-scope local later
      join
    end
  endtask

  // Same shape one level deeper: the reading branch is inside a nested
  // named block, and the written local sits two automatic block scopes
  // above it, all riding the one task frame.
  task automatic w2(input byte id, output byte r);
    begin: outer
      reg [7:0] acc;
      begin: inner
        reg [7:0] acc2;
        acc = id;
        acc2 = ~id;
        fork
          begin #5 ; end
          begin #20 r = acc ^ acc2; end
        join
      end
    end
  endtask

  // Overlapping calls: each invocation's frame must stay independent while
  // both are suspended inside their forks.
  byte r1, r2, r3, r4;

  initial begin
    automatic bit ok = 1;

    w(8'ha1, r1);
    if (r1 !== 8'ha1) begin ok = 0; $display("FAIL w r1=%0h exp a1", r1); end

    fork
      w(8'h5a, r2);
      w(8'hc3, r3);
    join
    if (r2 !== 8'h5a) begin ok = 0; $display("FAIL overlap r2=%0h exp 5a", r2); end
    if (r3 !== 8'hc3) begin ok = 0; $display("FAIL overlap r3=%0h exp c3", r3); end

    w2(8'h0f, r4);
    if (r4 !== 8'hff) begin ok = 0; $display("FAIL nested r4=%0h exp ff", r4); end

    if (ok) $display("PASS: automatic task frame sharing (fork sibling reads)");
    $finish;
  end
endmodule
