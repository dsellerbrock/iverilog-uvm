module test;
  bit clk = 0, value = 0;
  bit edge_clk = 0;

  covergroup event_strobe_cg @(posedge clk);
    type_option.strobe = 1;
    cp: coverpoint value { bins one = {1}; ignore_bins zero = {0}; }
  endgroup

  covergroup event_immediate_cg @(posedge clk);
    cp: coverpoint value { bins one = {1}; ignore_bins zero = {0}; }
  endgroup

  covergroup explicit_strobe_cg;
    type_option.strobe = 1;
    cp: coverpoint value { bins one = {1}; ignore_bins zero = {0}; }
  endgroup

  covergroup multi_immediate_cg @(posedge edge_clk);
    option.at_least = 2;
    cp: coverpoint value { bins one = {1}; }
  endgroup

  covergroup multi_strobe_cg @(posedge edge_clk);
    type_option.strobe = 1;
    option.at_least = 2;
    cp: coverpoint value { bins one = {1}; }
  endgroup

  event_strobe_cg event_strobe = new;
  event_immediate_cg event_immediate = new;
  explicit_strobe_cg explicit_strobe = new;
  multi_immediate_cg multi_immediate;
  multi_strobe_cg multi_strobe;

  initial begin
    // A procedural sample() call is immediate even when strobe is set.
    explicit_strobe.sample();
    value = 1;
    explicit_strobe.sample();
    if (explicit_strobe.get_inst_coverage() != 100.0)
      $fatal(1, "procedural sample() was deferred by type_option.strobe");

    value = 0;
    #1;
    clk = 1;
    value <= 1;
    #1;
    if (event_immediate.get_inst_coverage() != 0.0)
      $fatal(1, "non-strobe clock sample did not see the pre-NBA value");
    if (event_strobe.get_inst_coverage() != 100.0)
      $fatal(1, "strobe clock sample did not see the post-NBA value");

    // Both positive edges are in one time slot. The immediate group
    // counts both; the strobe group coalesces them into one sample.
    multi_immediate = new;
    multi_strobe = new;
    #1;
    edge_clk = 1;
    #0 edge_clk = 0;
    #0 edge_clk = 1;
    #1;
    if (multi_immediate.get_inst_coverage() != 100.0)
      $fatal(1, "immediate group did not count both same-slot edges");
    if (multi_strobe.get_inst_coverage() != 0.0)
      $fatal(1, "strobe group did not filter same-slot clock events");

    $display("ISSUE1410_COVERGROUP_STROBE_PASS");
    $display("PASSED");
    $finish;
  end
endmodule
