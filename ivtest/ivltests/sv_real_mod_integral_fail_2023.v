module sv_real_mod_integral_fail_2023;
  real r = 5.5;
  real q;

  initial begin
    q = r % 2.0;
    r %= 2.0;
  end
endmodule
