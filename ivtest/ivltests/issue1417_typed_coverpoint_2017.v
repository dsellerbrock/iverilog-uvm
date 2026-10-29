module test;
  int raw = 6;
  covergroup cg;
    bit [1:0] typed: coverpoint raw { bins two = {2}; }
  endgroup

  cg cov = new;
  initial begin
    cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "typed coverpoint conversion did not cover bin two: %0.1f",
             cov.get_inst_coverage());
    $display("PASSED");
  end
endmodule
