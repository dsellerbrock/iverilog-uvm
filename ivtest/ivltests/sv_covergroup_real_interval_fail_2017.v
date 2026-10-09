module sv_covergroup_real_interval_fail_2017;
  int value;

  covergroup cg;
    type_option.real_interval = 0.01;
    cp: coverpoint value { bins zero = {0}; }
  endgroup
endmodule
