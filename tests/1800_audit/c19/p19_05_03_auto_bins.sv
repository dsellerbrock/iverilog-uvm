module test;
  logic [3:0] v;
  covergroup cg;
    option.auto_bin_max = 4;
    cp: coverpoint v;
  endgroup
  cg cov = new();
  initial begin
    for (int i = 0; i < 16; i++) begin
      v = i;
      cov.sample();
    end
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "automatic-bin coverage=%0f, expected 100", cov.get_inst_coverage());
    $display("P19_05_03_AUTO_BINS_PASS");
    $finish;
  end
endmodule
