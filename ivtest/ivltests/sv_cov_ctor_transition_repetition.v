module test;
  covergroup cg(int lo=-1, int hi=2) with function sample(int value, bit en=1);
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      bins go = (lo [->2] => hi) iff (en);
      bins noncon = (lo [=2] => hi) iff (en);
    }
  endgroup
  cg c;
  int lo, hi;
  initial begin
    lo=-1; hi=2; c=new(lo,hi); lo=7; hi=8;
    c.sample(-1); c.sample(0); c.sample(-1); c.sample(2,0);
    if (c.get_inst_coverage()!=0.0) $fatal(1,"iff counted completion");
    c.sample(-1); c.sample(0); c.sample(-1); c.sample(2,1);
    if (c.get_inst_coverage()!=100.0) $fatal(1,"goto/nonconsecutive/default/freeze %f",c.get_inst_coverage());
    $display("PASSED"); $finish(0);
  end
endmodule
