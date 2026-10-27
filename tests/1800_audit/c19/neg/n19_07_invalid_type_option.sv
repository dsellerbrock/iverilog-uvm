// IEEE 1800-2017/2023 Tables 19-1 and 19-3: auto_bin_max is an instance option.
module test_neg_type_opt;
  bit a;
  covergroup cg;
    type_option.auto_bin_max = 4;
    coverpoint a;
  endgroup
  cg c = new;
endmodule
