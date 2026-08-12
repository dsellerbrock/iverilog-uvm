class atomic_visibility_item;
  static rand bit shared;
  static rand bit [7:0] dynamic_value[];
  bit enable_dynamic;
  bit [7:0] dynamic_target;

  constraint dynamic_c {
    if (enable_dynamic) {
      dynamic_value.size() == 1;
      foreach (dynamic_value[i]) dynamic_value[i] == dynamic_target;
    }
  }
endclass

module test;
  atomic_visibility_item item;
  int changes;

  always @(atomic_visibility_item::shared)
    changes++;

  initial begin
    item = new;
    atomic_visibility_item::shared = 1'b0;
    atomic_visibility_item::dynamic_value = new[1];
    atomic_visibility_item::dynamic_value[0] = 8'h17;
    #0;
    changes = 0;

    // Tentative static values from a failing solve must never reach the
    // backing signal or its scheduler/VPI observers.
    if (item.randomize(shared) with { 1'b0; } !== 0)
      $fatal(1, "contradictory randomize unexpectedly succeeded");
    #0;
    if (atomic_visibility_item::shared !== 1'b0 || changes != 0)
      $fatal(1, "failed randomize exposed a tentative static value");

    // A successful solve that retains the baseline is still a transaction,
    // but it is not a value change and must not create a callback/event.
    if (item.randomize(shared) with { shared == 1'b0; } !== 1)
      $fatal(1, "same-value constrained randomize unexpectedly failed");
    #0;
    if (atomic_visibility_item::shared !== 1'b0 || changes != 0)
      $fatal(1, "same-value commit produced a spurious change");

    // A successful call publishes exactly its final value once.
    if (item.randomize(shared) with { shared == 1'b1; } !== 1)
      $fatal(1, "constrained randomize unexpectedly failed");
    #0;
    if (atomic_visibility_item::shared !== 1'b1 || changes != 1)
      $fatal(1, "successful randomize did not publish one final change");

    // Existing object-backed containers are mutated in place by element
    // writeback. Failure discards the overlay; success publishes its final
    // contents even when the container size itself did not change.
    item.enable_dynamic = 1'b1;
    item.dynamic_target = 8'h2a;
    if (item.randomize(dynamic_value) with { 1'b0; } !== 0)
      $fatal(1, "contradictory dynamic-array randomize succeeded");
    if (atomic_visibility_item::dynamic_value[0] !== 8'h17)
      $fatal(1, "failed randomize exposed a dynamic-array candidate");
    if (item.randomize(dynamic_value) !== 1)
      $fatal(1, "dynamic-array constrained randomize failed");
    if (atomic_visibility_item::dynamic_value[0] !== 8'h2a)
      $fatal(1, "dynamic-array final element was not committed");

    $display("PASSED");
  end
endmodule
