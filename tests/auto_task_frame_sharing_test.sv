// Automatic block locals must remain live while sibling fork branches use
// them, and recursive/overlapping calls must retain independent values.
// Frame sharing is an implementation choice, not the language contract.
// Earlier frame ownership bugs dropped a parent context when one sibling
// ended before another read it; recursive event routing also needs to select
// the current invocation rather than a similarly named caller scope.
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
  // above it.
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

  // Named blocking fork with its own declarations (the ivtest
  // automatic_events2 shape): a branch ending early must not disturb
  // the fork locals or parent-block locals read by a live sibling.
  task automatic w3(input byte id, output byte r);
    begin: body3
      reg [7:0] acc;
      acc = id;
      fork: threads
        reg [7:0] tmp;
        begin #5 tmp = acc; end        // branch A ends early
        begin #15 r = tmp ^ 8'hff; end // branch B reads fork-scope local later
      join
    end
  endtask

  // Recursive call whose recursion site sits inside the named block, with
  // a sibling fork branch reading the block local before and after the
  // nested call completes (the ivtest recursive_task shape).
  task automatic fact(input int n, output int f);
    begin: fb
      int t;
      fork
        begin
          if (n > 1) fact(n - 1, t);
          else t = 1;
          #1 f = n * t;
        end
        begin @f ; end   // sibling observes completion via the frame var
      join
    end
  endtask

  // Overlapping calls: each invocation's frame must stay independent while
  // both are suspended inside their forks.
  byte r1, r2, r3, r4, r5;
  int f4;

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

    w3(8'h3c, r5);
    if (r5 !== 8'hc3) begin ok = 0; $display("FAIL named-fork r5=%0h exp c3", r5); end

    fact(4, f4);
    if (f4 !== 24) begin ok = 0; $display("FAIL recursive fork f4=%0d exp 24", f4); end

    if (ok) $display("PASS: automatic task frame sharing (fork sibling reads)");
    $finish;
  end
endmodule
