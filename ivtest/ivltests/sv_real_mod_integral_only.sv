module sv_real_mod_integral_only;
  real r = 5.5, q;

  initial begin
    q = r % 2.0;
    r %= 2.0;
  end
endmodule
