module sv_assert_first_match_tied_locals;
  bit clk, left_start, right_start, right_end, now_tick, next_tick;
  bit and_start, and_write, and_end;
  int want, data, delta;
  int fail_now, fail_now_rev, fail_next, fail_next_rev;
  int pass_now, pass_now_rev, pass_next, pass_next_rev;
  int fail_and, pass_and, fail_held, pass_held;

  `define CHECK_OR(name, lhs, rhs, op, timing, passes, failures) \
    property name; \
      int x; \
      @(posedge clk) first_match((lhs) or (rhs)) op (timing && x == want); \
    endproperty \
    assert property (name) passes++; else failures++;

  `define LEFT  (left_start, x = 1) ##1 1'b1
  `define RIGHT (right_start, x = 2) ##[1:2] right_end
  `CHECK_OR(overlap,     `LEFT,  `RIGHT, |->, now_tick,  pass_now,      fail_now)
  `CHECK_OR(overlap_rev, `RIGHT, `LEFT,  |->, now_tick,  pass_now_rev,  fail_now_rev)
  `CHECK_OR(next_edge,   `LEFT,  `RIGHT, |=>, next_tick, pass_next,     fail_next)
  `CHECK_OR(next_rev,    `RIGHT, `LEFT,  |=>, next_tick, pass_next_rev, fail_next_rev)
  `undef LEFT
  `undef RIGHT
  `undef CHECK_OR

  // The right sibling must keep the value from before the fork. The left
  // sibling writes x, uses it in a same-tick guard, then uses it one tick
  // later in a dependent RHS. Its values must survive the wait for the join.
  property and_flow;
    int x = 7;
    logic [3:0] y;
    @(posedge clk)
      first_match(((and_start, x = data) ##0 (x == -2)
                    ##1 (and_write, y = x + delta)) and
                  (and_start ##2 (and_end && x == 7)))
      |-> (and_end && x == -2 && y == 3);
  endproperty
  assert property (and_flow) pass_and++; else fail_and++;

  // Two finishes of the ranged limb wait for the same other limb. Both
  // histories must survive in the held completion state of the AND.
  property and_tied;
    int x;
    @(posedge clk)
      first_match((and_start ##[1:2] (and_write, x = data)) and
                  (and_start ##3 and_end)) |-> (x == want);
  endproperty
  assert property (and_tied) pass_held++; else fail_held++;

  always @(posedge clk) begin
    if (and_start) data = 19;
    if (and_write) delta = 0;
  end

  task tick;
    #5 clk = 1;
    #1 clk = 0;
  endtask

  task or_attempt(input bit left_en, right_en, early_en, input int expected);
    left_start = left_en;
    right_start = right_en;
    want = expected;
    tick();
    left_start = 0;
    right_start = 0;
    now_tick = 1;
    right_end = early_en;
    tick();
    now_tick = 0;
    next_tick = 1;
    right_end = 1;
    tick();
    next_tick = 0;
    right_end = 0;
    tick();
  endtask

  task check_or(input int failures, passes);
    if (fail_now != failures || fail_now_rev != failures ||
        fail_next != failures || fail_next_rev != failures ||
        pass_now != passes || pass_now_rev != passes ||
        pass_next != passes || pass_next_rev != passes)
      $fatal(1, "OR failures %0d/%0d/%0d/%0d, passes %0d/%0d/%0d/%0d",
             fail_now, fail_now_rev, fail_next, fail_next_rev,
             pass_now, pass_now_rev, pass_next, pass_next_rev);
  endtask

  initial begin
    $assertvacuousoff(0);
    or_attempt(1, 1, 1, 1);
    check_or(1, 0);
    or_attempt(1, 1, 1, 2);
    check_or(2, 0);
    or_attempt(0, 1, 1, 2);
    check_or(2, 1);
    or_attempt(1, 1, 0, 1);
    check_or(2, 2);

    and_start = 1;
    data = -2;
    tick();
    and_start = 0;
    and_write = 1;
    delta = 21;
    data = 1;
    tick();
    and_end = 1;
    data = 2;
    tick();
    if (pass_and != 1 || fail_and || pass_held || fail_held)
      $fatal(1, "AND did not carry its typed local values to the join");
    want = 1;
    tick();
    if (pass_held || fail_held != 1)
      $fatal(1, "AND lost one of the held branch values");

    $display("PASS");
    $finish(0);
  end
endmodule
