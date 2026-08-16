// IEEE 1800-2017 19.5.2: goto and nonconsecutive repetition, sampling
// control, and transition bins used as cross-coverage operands.
module sv_covergroup_transition_modes;
  bit failed;

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %s", label);
      failed = 1;
    end
  endtask

  covergroup goto_cg with function sample(bit [3:0] value);
    cp: coverpoint value {
      bins twice = (1 => 2 [->2] => 3);
    }
  endgroup

  covergroup nonconsecutive_cg with function sample(bit [3:0] value);
    cp: coverpoint value {
      bins twice = (1 => 2 [=2] => 3);
    }
  endgroup

  covergroup gated_cg with function sample(bit [3:0] value, bit gate);
    cp: coverpoint value iff (gate) {
      bins step = (1 => 2 => 3);
    }
  endgroup

  covergroup stopped_cg with function sample(bit [3:0] value);
    cp: coverpoint value {
      bins step = (1 => 2 => 3);
    }
  endgroup

  covergroup crossed_cg with function sample(bit [3:0] lhs,
                                               bit [3:0] rhs);
    left_cp: coverpoint lhs {
      // 2 start values * 2 repetition lengths * 2 end values = 8 bins.
      bins paths[] = (1, 2 => 3 [*1:2] => 4, 5);
    }
    right_cp: coverpoint rhs {
      bins nine = {9};
    }
    path_cross: cross left_cp, right_cp;
  endgroup

  goto_cg goto_cov = new;
  nonconsecutive_cg nonconsecutive_cov = new;
  gated_cg gated_cov = new;
  stopped_cg stopped_cov = new;
  crossed_cg crossed_cov = new;

  initial begin
    int start_value;
    int repeat_count;
    int end_value;

    // Goto repetition permits gaps before the last occurrence, but the
    // following transition item must occur on the next sampled value.
    goto_cov.sample(1);
    goto_cov.sample(2);
    goto_cov.sample(7);
    goto_cov.sample(2);
    goto_cov.sample(6); // breaks the required immediate 2 => 3 edge
    goto_cov.sample(3);
    check("goto requires immediate successor", goto_cov.get_inst_coverage() == 0.0);
    goto_cov.sample(1);
    goto_cov.sample(2);
    goto_cov.sample(7);
    goto_cov.sample(2);
    goto_cov.sample(3);
    check("goto repetition", goto_cov.get_inst_coverage() == 100.0);

    // Nonconsecutive repetition permits a gap after the last occurrence as
    // well, but another repeated value before the successor invalidates that
    // completed attempt.
    nonconsecutive_cov.sample(1);
    nonconsecutive_cov.sample(2);
    nonconsecutive_cov.sample(7);
    nonconsecutive_cov.sample(2);
    nonconsecutive_cov.sample(6);
    nonconsecutive_cov.sample(2);
    nonconsecutive_cov.sample(3);
    check("nonconsecutive forbids extra repeated value",
          nonconsecutive_cov.get_inst_coverage() == 0.0);
    nonconsecutive_cov.sample(1);
    nonconsecutive_cov.sample(2);
    nonconsecutive_cov.sample(7);
    nonconsecutive_cov.sample(2);
    nonconsecutive_cov.sample(6);
    nonconsecutive_cov.sample(3);
    check("nonconsecutive repetition", nonconsecutive_cov.get_inst_coverage() == 100.0);

    // A coverpoint iff removes that sampling point from the transition.
    gated_cov.sample(1, 1);
    gated_cov.sample(15, 0);
    gated_cov.sample(2, 1);
    gated_cov.sample(3, 1);
    check("coverpoint iff freezes transition sampling",
          gated_cov.get_inst_coverage() == 100.0);

    // stop() suppresses both counts and transition progress.
    stopped_cov.stop();
    stopped_cov.sample(1);
    stopped_cov.sample(2);
    stopped_cov.sample(3);
    stopped_cov.start();
    stopped_cov.sample(3);
    check("stop suppresses transition progress", stopped_cov.get_inst_coverage() == 0.0);
    stopped_cov.sample(1);
    stopped_cov.sample(2);
    stopped_cov.sample(3);
    check("start restores transition sampling", stopped_cov.get_inst_coverage() == 100.0);

    // Exercise all compact family members and their corresponding automatic
    // cross bins. A transition contributes only on its completion sample.
    for (start_value = 1; start_value <= 2; start_value++) begin
      for (repeat_count = 1; repeat_count <= 2; repeat_count++) begin
        for (end_value = 4; end_value <= 5; end_value++) begin
          crossed_cov.sample(15, 9);
          crossed_cov.sample(start_value, 9);
          repeat (repeat_count) crossed_cov.sample(3, 9);
          crossed_cov.sample(end_value, 9);
        end
      end
    end
    check("arrayed transition cross", crossed_cov.get_inst_coverage() == 100.0);

    if (failed) $finish(1);
    $display("PASSED");
    $finish;
  end
endmodule
