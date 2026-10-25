module sv_covergroup_option_scope_fail;
  bit a;
  covergroup cg;
    cp_a: coverpoint a {
      option.per_instance = 1;
      type_option.strobe = 1;
      option.cross_num_print_missing = 1;
      type_option.auto_bin_max = 4;
    }
    cp_b: coverpoint a;
    x: cross cp_a, cp_b {
      option.auto_bin_max = 4;
    }
  endgroup
endmodule
