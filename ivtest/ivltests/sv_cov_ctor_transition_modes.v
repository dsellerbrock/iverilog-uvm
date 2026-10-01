module test;
  covergroup cg(int lo, int hi) with function sample(int signed value);
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      bins consecutive = (lo => hi [*2]);
      bins alternatives[] = (lo, lo+1 => hi);
    }
  endgroup
  cg c;
  int i;
  initial begin
    c = new(-2,1);
    c.sample(-2); c.sample(1); c.sample(1);
    if (c.get_inst_coverage() <= 0.0) $fatal(1,"dynamic program did not complete");
    for (i=0;i<16;i++) begin c.sample(-1); c.sample(1); end
    if (c.get_inst_coverage() != 100.0) $fatal(1,"alternatives/repetition %f",c.get_inst_coverage());
    $display("PASSED"); $finish(0);
  end
endmodule
