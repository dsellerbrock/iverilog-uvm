// IEEE 1800-2017/2023 §19.6: expressions cannot be direct cross items.
module test;
  bit a, b;
  covergroup cg;
    ca: coverpoint a;
    invalid: cross ca, (b + 1);
  endgroup
  cg cov = new;
endmodule
