module issue1204_sample_formal_option_fail;
  bit a;
  int x = 4;

  covergroup cg with function sample(int x);
    option.weight = x;
    cp: coverpoint a;
  endgroup

  cg c = new;
endmodule
