module std_randomize_conditional_soft_test;
  bit [7:0] a_source;
  bit in_reset;
  bit use_last_a_source_released;
  bit [7:0] last_a_source_released;
  bit [7:0] a_source_pend_q[$];
  int unsigned valid_a_source_width;

  task automatic randomize_source;
    if (!std::randomize(a_source) with {
          (!in_reset) -> soft !(a_source inside {a_source_pend_q});
          (a_source >> valid_a_source_width) == 0;
          use_last_a_source_released &&
              !(last_a_source_released inside {a_source_pend_q})
            -> soft (a_source == last_a_source_released);
        })
      $fatal(1, "conditional-soft scope randomization failed");
  endtask

  initial begin
    valid_a_source_width = 1;
    last_a_source_released = 0;
    a_source_pend_q.push_back(0);

    // Both guards are false. The only hard restriction is a_source < 2.
    // The historical lowering deleted the guards and `soft` keywords,
    // producing the contradictory hard pair a_source!=0 and a_source==0.
    in_reset = 1;
    use_last_a_source_released = 0;
    randomize_source();
    if (a_source > 1)
      $fatal(1, "hard width constraint was not enforced: %0d", a_source);

    // With the first guard active, the feasible soft preference must avoid
    // the pending source 0 and therefore select the only alternative, 1.
    in_reset = 0;
    randomize_source();
    if (a_source != 1)
      $fatal(1, "guarded soft constraint was not preferred: %0d", a_source);

    $display("PASSED: conditional soft std::randomize constraints");
  end
endmodule
