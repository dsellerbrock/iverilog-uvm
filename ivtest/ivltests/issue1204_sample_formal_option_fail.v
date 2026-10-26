module test;
  bit a;
  covergroup cg with function sample(int x);
    option.weight = x;
    cp: coverpoint a;
  endgroup
endmodule
