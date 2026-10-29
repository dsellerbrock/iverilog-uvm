module test;
  bit clk = 0, data = 0;
  clocking cb_pre @(posedge clk); input #1step data; endclocking
  clocking cb_obs @(posedge clk); input #0 data; endclocking

  covergroup pre_cg @(posedge clk);
    cp: coverpoint cb_pre.data {
      bins old = {0};
      ignore_bins new_value = {1};
    }
  endgroup

  covergroup obs_cg @(posedge clk);
    cp: coverpoint cb_obs.data {
      bins old = {0};
      ignore_bins new_value = {1};
    }
  endgroup

  pre_cg pre = new;
  obs_cg obs = new;

  initial begin
    #5; data = 1; clk = 1; #1;
    if (pre.get_inst_coverage() != 100.0)
      $fatal(1, "#1step coverpoint did not sample the Preponed value");
    if (obs.get_inst_coverage() != 0.0)
      $fatal(1, "#0 coverpoint did not sample the Observed value");
    $display("ISSUE1414_CLOCKING_BLOCK_COVERPOINT_PASS");
    $display("PASSED");
    $finish;
  end
endmodule
