module sv_covergroup_type_real_interval_cross_fail_2023;
  bit a;
  covergroup cg;
    cp_a: coverpoint a;
    cp_b: coverpoint a;
    x: cross cp_a, cp_b {
      type_option.real_interval = 1.0;
    }
  endgroup
endmodule
