// IEEE 1800-2017 19.5.1 and 19.5.2: a bins-level iff is a
// per-bin count guard. It is evaluated at every sampling point, with X/Z
// treated as false, but it does not stop transition-sequence recognition.
module sv_covergroup_bin_iff;
  bit failed;
  logic clk;
  logic [3:0] event_value;
  logic event_gate;

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %s", label);
      failed = 1;
    end
  endtask

  covergroup value_cg with function sample(logic [3:0] value,
                                             logic gate);
    cp: coverpoint value {
      bins guarded = {3} iff (gate);
    }
  endgroup

  covergroup wildcard_cg with function sample(logic [3:0] value,
                                                logic gate);
    cp: coverpoint value {
      wildcard bins guarded = {4'b1??1}
        iff (gate && ($countones(value) > 1));
    }
  endgroup

  covergroup transition_cg with function sample(logic [3:0] value,
                                                  logic gate);
    cp: coverpoint value {
      bins guarded = (1 => 2 [*2] => 3) iff (gate);
    }
  endgroup

  covergroup event_cg @(posedge clk);
    cp: coverpoint event_value {
      bins guarded = {9} iff (event_gate);
    }
  endgroup

  value_cg value_cov = new;
  wildcard_cg wildcard_cov = new;
  transition_cg transition_cov = new;
  transition_cg transition_blocked = new;
  event_cg event_cov = new;

  initial begin
    value_cov.sample(3, 1'b0);
    value_cov.sample(3, 1'bx);
    check("false and X value-bin guards", value_cov.get_inst_coverage() == 0.0);
    value_cov.sample(3, 1'b1);
    check("true value-bin guard", value_cov.get_inst_coverage() == 100.0);

    event_value = 9;
    event_gate = 1;
    check("countones guard expression", $countones(event_value) > 1);
    check("logical countones guard expression",
          event_gate && ($countones(event_value) > 1));
    wildcard_cov.sample(4'b1001, 1'b0);
    check("wildcard guard false", wildcard_cov.get_inst_coverage() == 0.0);
    wildcard_cov.sample(4'b1001, 1'b1);
    check("wildcard expression guard", wildcard_cov.get_inst_coverage() == 100.0);

    // False guards on intermediate samples must not freeze the NFA. The
    // guard is true only on the completion sample, so this still counts.
    transition_cov.sample(1, 1'b0);
    transition_cov.sample(2, 1'b0);
    transition_cov.sample(2, 1'bx);
    transition_cov.sample(3, 1'b1);
    check("transition guard gates count, not recognition",
          transition_cov.get_inst_coverage() == 100.0);

    // Conversely, a false completion guard consumes the recognized
    // transition without incrementing its bin.
    transition_blocked.sample(1, 1'b1);
    transition_blocked.sample(2, 1'b1);
    transition_blocked.sample(2, 1'b1);
    transition_blocked.sample(3, 1'b0);
    check("transition completion guard false",
          transition_blocked.get_inst_coverage() == 0.0);

    // Pin the automatic event-driven path used by interface covergroups.
    event_value = 9;
    event_gate = 0;
    #1 clk = 1;
    #1 clk = 0;
    #1;
    check("event-driven bin guard false", event_cov.get_inst_coverage() == 0.0);
    event_gate = 1;
    #1 clk = 1;
    #1 clk = 0;
    #1;
    check("event-driven bin guard true", event_cov.get_inst_coverage() == 100.0);

    if (failed) $finish(1);
    $display("PASSED");
    $finish;
  end
endmodule
