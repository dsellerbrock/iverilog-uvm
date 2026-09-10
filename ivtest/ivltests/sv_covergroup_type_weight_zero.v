module test;
  covergroup cg with function sample(int v);
    type_option.weight=0;
    cp: coverpoint v { bins b[]={[0:1]}; }
  endgroup
  cg a,b;
  initial begin
    a=new; b=new; a.sample(0);
    if ($get_coverage()!=100.0) $fatal(1,"all zero type weights");
    if (a.get_coverage()!=25.0) $fatal(1,"type weight changed instance averaging");
    $display("PASSED");
  end
endmodule
