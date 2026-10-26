module issue1204_sample_formal_option_fail;
  bit a;
  covergroup cg with function sample(int x);
    option.weight = x;
    cp: coverpoint a;
  endgroup
endmodule
