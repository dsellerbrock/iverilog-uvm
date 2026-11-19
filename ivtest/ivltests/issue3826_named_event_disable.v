module issue3826_late_disable (
  input bit clk, start, keep, result,
  input logic gate,
  input bit reset,
  output int failures = 0
);
  assert property (@(posedge clk) start ##1 keep |-> ##1 result)
  else failures++;

  default disable iff
    ((issue3826_named_event_disable.ev.triggered && gate) || reset);
endmodule

module issue3826_named_event_disable #(parameter int N = 1);
  bit clk, start, reset, result;
  logic gate = 0;
  bit keep = 1;
  event ev, unrelated;
  event alias_ev = ev;
  int fixed_failures = 0, repeat_failures = 0, late_failures;

  assert property (@(posedge clk) disable iff ((ev.triggered && gate) || reset)
                   start ##1 keep |-> ##1 result)
  else fixed_failures++;

  assert property (@(posedge clk)
                   disable iff ((alias_ev.triggered() && gate) || reset)
                   start ##1 keep[*N] |-> ##1 result)
  else repeat_failures++;

  issue3826_late_disable late_disable
    (clk, start, keep, result, gate, reset, late_failures);

  bit start_extra, expire_gate, pair_gate;
  event pulse, expires, left, right;
  int pulse_failures = 0, expire_failures = 0, pair_failures = 0;

  assert property (@(posedge clk) disable iff (pulse.triggered)
                   start_extra |-> ##1 result)
  else pulse_failures++;

  assert property (@(posedge clk) disable iff (expire_gate && !expires.triggered)
                   start_extra |-> ##1 result)
  else expire_failures++;

  assert property (@(posedge clk)
                   disable iff (pair_gate && (left.triggered != right.triggered))
                   start_extra |-> ##1 result)
  else pair_failures++;

  task tick;
    #5 clk = 1;
    #1 clk = 0;
  endtask

  task launch;
    start = 1;
    tick();
    start = 0;
    tick();
  endtask

  task check_failures(input int fixed_count, repeat_count, late_count);
    tick();
    if (fixed_failures !== fixed_count || repeat_failures !== repeat_count ||
        late_failures !== late_count)
      $fatal(1, "expected %0d/%0d/%0d verdicts, got %0d/%0d/%0d",
             fixed_count, repeat_count, late_count,
             fixed_failures, repeat_failures, late_failures);
  endtask

  initial begin
    // An unrelated trigger and triggers masked by 0 or X preserve attempts.
    launch();
    gate = 1;
    -> unrelated;
    gate = 0;
    -> ev;
    #1 gate = 1'bx;
    -> ev;
    gate = 0;
    check_failures(1, 1, 1);

    // A later pulse cancels synchronously, even though the gate falls
    // before the abort process executes. The alias observes the same event.
    launch();
    gate = 1;
    -> ev;
    gate = 0;
    check_failures(1, 1, 1);

    // A gate transition can also qualify an already-triggered event.
    launch();
    -> alias_ev;
    gate = 1;
    gate = 0;
    check_failures(1, 1, 1);

    // Ordinary signal dependencies remain active in the mixed predicate.
    launch();
    reset = 1;
    reset = 0;
    check_failures(1, 1, 1);

    // Rebinding the alias stops it observing the old synchronization queue.
    launch();
    alias_ev = unrelated;
    gate = 1;
    -> ev;
    gate = 0;
    check_failures(1, 2, 1);

    launch();
    gate = 1;
    -> unrelated;
    gate = 0;
    check_failures(2, 2, 2);

    start_extra = 1;
    tick();
    start_extra = 0;
    -> pulse;
    -> expires;
    expire_gate = 1;
    -> left;
    -> right;
    pair_gate = 1;
    // The isolated negated term becomes true at the next time step.
    // The pair expires together and remains equal.
    #1;
    expire_gate = 0;
    pair_gate = 0;
    tick();
    if (pulse_failures !== 0 || expire_failures !== 0 || pair_failures !== 1)
      $fatal(1, "event-only/expiration/pair verdicts %0d/%0d/%0d",
             pulse_failures, expire_failures, pair_failures);

    // One event can disable the pair. The other two attempts reach a verdict.
    start_extra = 1;
    tick();
    start_extra = 0;
    pair_gate = 1;
    -> left;
    pair_gate = 0;
    tick();
    if (pulse_failures !== 1 || expire_failures !== 1 || pair_failures !== 1)
      $fatal(1, "control verdicts %0d/%0d/%0d",
             pulse_failures, expire_failures, pair_failures);

    $display("PASS asynchronous named-event disable");
    $finish(0);
  end
endmodule
