// IEEE 1800-2017 §19.11.2 (p. 588) / IEEE 1800-2023 §19.11.2 (p. 616)
// Probe the two-argument get_inst_coverage() overload on cross items.
module test;
  covergroup cg with function sample(bit a, bit b);
    cp_a: coverpoint a;
    cp_b: coverpoint b;
    x_ab: cross cp_a, cp_b;
  endgroup

  initial begin
    int cov, tot;
    cg g = new;
    void'(g.x_ab.get_inst_coverage(cov, tot));
  end
endmodule
