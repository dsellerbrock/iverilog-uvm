// Queue concatenation assignment evaluates its complete right-hand value
// before changing the destination queue (IEEE 1800-2017 7.10.4 and 10.10).
module main;
  int q[$];
  int bounded[$:2];
  int calls;
  bit failed;
  bit woke;

  function automatic int mark(input int value);
    calls += 1;
    return value;
  endfunction

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    failed = 1'b0;
    woke = 1'b0;

    // Scalar operands can still read the destination. Neither read may see
    // an element written by an earlier operand.
    q = {1, 2};
    q = {q[1], q[0]};
    check("scalar self-swap", q.size() == 2 && q[0] == 2 && q[1] == 1);

    // Whole and sliced collection operands splice the pre-assignment value.
    q = {1, 2, 3};
    q = {q, 4};
    check("append self", q.size() == 4 && q[0] == 1 && q[3] == 4);
    q = {0, q};
    check("prepend self", q.size() == 5 && q[0] == 0 && q[4] == 4);
    q = {q[0:1], 9, q[2:$]};
    check("slice insert", q.size() == 6 && q[0] == 0 && q[1] == 1
          && q[2] == 9 && q[3] == 2 && q[5] == 4);

    // The final whole-queue store must retain ordinary mutation wakeups.
    fork
      begin
        wait (q.size() == 7);
        woke = 1'b1;
      end
    join_none
    #0;
    q = {q, 10};
    #0;
    check("wait notification", woke && q[6] == 10);

    // A bounded destination keeps the leftmost N+1 values, but every RHS
    // operand is evaluated before the excess tail is discarded.
    calls = 0;
    bounded = {mark(1), mark(2), mark(3), mark(4)};
    check("bounded prefix", bounded.size() == 3
          && bounded[0] == 1 && bounded[1] == 2 && bounded[2] == 3);
    check("bounded evaluates tail", calls == 4);

    bounded = {5, 6};
    bounded = {0, bounded};
    check("bounded self prepend", bounded.size() == 3
          && bounded[0] == 0 && bounded[1] == 5 && bounded[2] == 6);

    if (failed)
      $fatal(1, "queue concatenation snapshot checks failed");
    $display("PASSED");
  end
endmodule
