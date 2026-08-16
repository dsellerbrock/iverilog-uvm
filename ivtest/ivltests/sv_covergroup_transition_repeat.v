// IEEE 1800-2017 19.5.3: bounded consecutive repetition in transition
// bins.  The long arrayed bin mirrors Caliptra's generated register
// coverage shape and must remain compact: it represents 1000 logical bins,
// not an eagerly expanded sum of 1+...+1000 NFA steps.
module sv_covergroup_transition_repeat;
  bit failed;

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %s", label);
      failed = 1;
    end
  endtask

  covergroup bounded_cg with function sample(bit [3:0] value);
    cp: coverpoint value {
      bins exact = (1 => 2 [*3] => 3);
      bins ranged = (4 => 5 [*2:4] => 6);
      bins split[] = (8, 9 => 0 [*1:3] => 10, 11);
    }
  endgroup

  covergroup overlap_cg with function sample(bit [3:0] value);
    option.at_least = 3;
    cp: coverpoint value {
      bins triple = (7 [*3]);
    }
  endgroup

  covergroup long_cg with function sample(bit [3:0] value);
    cp: coverpoint value {
      bins wait_bins[] = (12 => 0 [*1:1000] => 13);
    }
  endgroup

  bounded_cg bounded = new;
  overlap_cg overlap = new;
  long_cg long_wait = new;

  initial begin
    int start_value;
    int repeat_count;
    int end_value;

    // Exact repetition and both ends of a repetition range hit one bin each.
    bounded.sample(1);
    repeat (3) bounded.sample(2);
    bounded.sample(3);
    bounded.sample(4);
    repeat (2) bounded.sample(5);
    bounded.sample(6);
    bounded.sample(4);
    repeat (4) bounded.sample(5);
    bounded.sample(6);

    // split[] has 2 * 3 * 2 = 12 bounded transitions.  Exercise every one.
    for (start_value = 8; start_value <= 9; start_value++) begin
      for (repeat_count = 1; repeat_count <= 3; repeat_count++) begin
        for (end_value = 10; end_value <= 11; end_value++) begin
          bounded.sample(15); // break any pending transition
          bounded.sample(start_value);
          repeat (repeat_count) bounded.sample(0);
          bounded.sample(end_value);
        end
      end
    end
    check("bounded and split repetition", bounded.get_inst_coverage() == 100.0);

    // Five equal samples contain three overlapping length-three matches.
    repeat (5) overlap.sample(7);
    check("overlapping repetition counts once per completion sample",
          overlap.get_inst_coverage() == 100.0);

    // One of 1000 compact logical bins is hit.
    long_wait.sample(12);
    long_wait.sample(0);
    long_wait.sample(13);
    check("long compact transition family",
          long_wait.get_inst_coverage() > 0.099 &&
          long_wait.get_inst_coverage() < 0.101);

    if (failed) $finish(1);
    $display("PASSED");
    $finish;
  end
endmodule
