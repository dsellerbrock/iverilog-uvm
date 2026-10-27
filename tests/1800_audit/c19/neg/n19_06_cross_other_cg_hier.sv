// IEEE 1800-2017 p. 572 / 2023 p. 599: Attempts to cross items from different
// coverage groups shall result in a compiler error.
module test_other_cg_hier;
  bit a, b;
  covergroup first;
    ca: coverpoint a;
  endgroup
  first one = new;
  covergroup second;
    cb: coverpoint b;
    invalid: cross one.ca, cb;
  endgroup
  second two = new;
endmodule
