module sv_covergroup_real_interval_fail_2023;
  real value;

  covergroup invalid_interval;
    type_option.real_interval = 0.0;
    cp: coverpoint value { bins b[] = {[0.0:1.0]}; }
  endgroup

  covergroup missing_interval;
    cp: coverpoint value { bins b[] = {[0.0:1.0]}; }
  endgroup

  covergroup huge_interval;
    type_option.real_interval = 1.0e-308;
    cp: coverpoint value { bins b[] = {[-1.0e308:1.0e308]}; }
  endgroup
endmodule
