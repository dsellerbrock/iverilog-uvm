module test;
  covergroup cg(int w);
    type_option.weight=w;
  endgroup
  cg a;
  initial a=new(3);
endmodule
