class real_randc_array;
  randc real values[2];
endclass

module test;
  real_randc_array a;
  initial a = new;
endmodule
