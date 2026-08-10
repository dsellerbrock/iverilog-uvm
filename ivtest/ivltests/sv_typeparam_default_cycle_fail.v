// Mutually dependent type defaults are an invalid concrete parameter binding.
// Diagnosing the cycle must terminate instead of recursively trying to solve it.
module sv_typeparam_default_cycle_fail;
  class cycle #(type A = B, type B = A);
    A a;
    B b;
  endclass

  initial begin
    cycle #() bad;
    bad = new;
  end
endmodule
