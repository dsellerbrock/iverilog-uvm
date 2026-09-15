module test;
  covergroup cg(int lo, int hi) with function sample(int value);
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      option.at_least = 2;
      bins named = (lo, lo => hi, hi);
    }
  endgroup
  cg c;
  initial begin
    c = new(0,1);
    c.sample(0); c.sample(1);
    if (c.get_inst_coverage() != 0.0) $fatal(1,"named bin bumped twice per sample");
    c.sample(0); c.sample(1);
    if (c.get_inst_coverage() != 100.0) $fatal(1,"named bin did not reach at_least");
    $display("PASSED"); $finish(0);
  end
endmodule
