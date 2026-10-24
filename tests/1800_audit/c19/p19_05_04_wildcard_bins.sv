module test;
  logic [3:0] v;
  covergroup cg;
    cp: coverpoint v { wildcard bins w = {4'b11??}; }
  endgroup
  cg cov = new();
  initial begin
    v = 4'b1010; cov.sample();
    if (cov.get_inst_coverage() != 0.0)
      $fatal(1, "nonmatching wildcard value covered: %0f", cov.get_inst_coverage());
    v = 4'b1111; cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "wildcard-bin coverage=%0f, expected 100", cov.get_inst_coverage());
    $display("P19_05_04_WILDCARD_BINS_PASS");
    $finish;
  end
endmodule
