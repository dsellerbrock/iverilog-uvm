module test;
  covergroup cg(int signed lo, int signed hi) with function sample(int signed value);
    option.get_inst_coverage=1;
    cp: coverpoint value { bins paths[] = ([lo:hi] => 2); }
  endgroup
  cg c;
  int i;
  initial begin
    c=new(-2,1);
    for(i=-2;i<=1;i++) begin c.sample(i); c.sample(2); end
    if(c.get_inst_coverage()!=100.0) $fatal(1,"signed cross-zero %f",c.get_inst_coverage());
    $display("PASSED"); $finish(0);
  end
endmodule
