class real_randc_unsupported;
  randc real value;
endclass

module test;
  real_randc_unsupported item;
  initial item = new;
endmodule
