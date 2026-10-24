module sv_covergroup_type_option_instance_fail_2023;
  bit a;
  covergroup cg;
    type_option.auto_bin_max = 4;
    coverpoint a;
  endgroup
  cg c = new;
endmodule
