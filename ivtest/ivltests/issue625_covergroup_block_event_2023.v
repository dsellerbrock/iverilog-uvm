module issue625_covergroup_block_event;
  int sampled_value = 0;

  covergroup completed_cg @@(end t1);
    option.at_least = 2;
    value_cp: coverpoint sampled_value {
      bins completed_value = {2};
    }
  endgroup

  covergroup disabled_cg @@(end t2);
    value_cp: coverpoint sampled_value {
      bins disabled_value = {2};
    }
  endgroup

  completed_cg completed = new;
  disabled_cg disabled = new;

  task t1;
    sampled_value = 1;
    sampled_value = 2;
  endtask

  task t2;
    sampled_value = 2;
    disable t2;
    sampled_value = 3;
  endtask

  initial begin
    if (completed.get_inst_coverage() != 0.0)
      $fatal(1, "covergroup sampled before t1");

    t1();
    if (completed.get_inst_coverage() != 0.0)
      $fatal(1, "end t1 sampled more than once on one call or before its last statement");

    t1();
    if (completed.get_inst_coverage() != 100.0)
      $fatal(1, "end t1 did not sample once after each call");

    t2();
    if (disabled.get_inst_coverage() != 0.0)
      $fatal(1, "end t2 fired after the task was disabled");

    $display("PASSED");
    $display("issue 625 covergroup end task event");
    $finish;
  end
endmodule
