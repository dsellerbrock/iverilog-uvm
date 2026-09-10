module test;
 covergroup cg with function sample(int v);
  cp: coverpoint v;
 endgroup
 cg a;
 initial begin a=new; a.option.get_inst_coverage=1; end
endmodule
