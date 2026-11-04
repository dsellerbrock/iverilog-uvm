module issue1411_covergroup_ref_event;
  bit clk_a = 0;
  bit clk_b = 0;
  bit value = 0;

  covergroup cg(ref bit clock_arg) @(posedge clock_arg);
    cp: coverpoint value { bins zero = {0}; bins one = {1}; }
  endgroup

  cg cov_a = new(clk_a);
  cg cov_b = new(clk_b);

  initial begin
    #1; value = 1; clk_a = 1; #1;
    $display("A_AFTER_A=%0.1f B_AFTER_A=%0.1f",
             cov_a.get_inst_coverage(), cov_b.get_inst_coverage());

    clk_a = 0; #1; value = 0; clk_b = 1; #1;
    $display("A_AFTER_B=%0.1f B_AFTER_B=%0.1f",
             cov_a.get_inst_coverage(), cov_b.get_inst_coverage());

    value = 1; clk_b = 0; #1; clk_b = 1; #1;
    $display("A_FINAL=%0.1f B_FINAL=%0.1f",
             cov_a.get_inst_coverage(), cov_b.get_inst_coverage());
  end
endmodule
