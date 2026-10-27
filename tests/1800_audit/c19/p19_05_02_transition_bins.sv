module test;
  logic [3:0] v;
  covergroup cg;
    cp: coverpoint v { bins t = (1 => 2 => 3); }
  endgroup
  cg cov = new();
  initial begin
    v = 1; cov.sample();
    v = 2; cov.sample();
    v = 3; cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "transition-bin coverage=%0f, expected 100", cov.get_inst_coverage());
    $display("P19_05_02_TRANSITION_BINS_PASS");
    $finish;
  end
endmodule
