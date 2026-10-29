module issue1433_cross_real_variable_fail;
  real r;
  bit b;
  covergroup cg;
    invalid: cross r, b;
  endgroup
endmodule
