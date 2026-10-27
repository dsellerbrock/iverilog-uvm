module sv_covergroup_dup_option;
  bit a;
  covergroup cg;
    option.weight = 1;
    option.weight = 2;
    coverpoint a;
  endgroup
  cg c = new;
endmodule
