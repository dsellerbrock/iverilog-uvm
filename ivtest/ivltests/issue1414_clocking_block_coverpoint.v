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
    #5;
    data = 1;
    clk = 1;
    #1;
    if (pre.get_inst_coverage() != 100.0)
      $fatal(1, "#1step clocking coverpoint coverage %0.1f",
             pre.get_inst_coverage());
    if (obs.get_inst_coverage() != 0.0)
      $fatal(1, "#0 clocking coverpoint coverage %0.1f",
             obs.get_inst_coverage());
    $display("PASS: issue1414 clocking-block coverpoint bins");
    $display("PASSED");
    $finish;
  end
endmodule
