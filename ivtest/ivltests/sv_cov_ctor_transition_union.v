module test;
  covergroup cg(int lo, int hi) with function sample(int value);
    type_option.merge_instances = 1;
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      bins path[] = (lo => hi);
    }
  endgroup
  cg a, b, overlap;
  real got;
  initial begin
    a = new(0,1); b = new(2,3); overlap = new(0,1);
    a.sample(0); a.sample(1);
    got = a.get_coverage();
    if (got < 49.999999 || got > 50.000001) $fatal(1,"union %f",got);
    if (a.get_inst_coverage() != 100.0 || b.get_inst_coverage() != 0.0)
      $fatal(1,"instance coverage");
    overlap.sample(0); overlap.sample(1);
    if (a.get_coverage() != 50.0) $fatal(1,"overlap duplicated bin");
    $display("PASSED"); $finish(0);
  end
endmodule
