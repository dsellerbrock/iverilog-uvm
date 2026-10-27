// IEEE 1800-2017/2023 §19.6: cross items must belong to the enclosing group.
`default_nettype none
module test;
  bit a, b;
  covergroup first;
    ca: coverpoint a;
  endgroup
  covergroup second;
    cb: coverpoint b;
    invalid: cross ca, cb;
  endgroup
  first one = new;
  second two = new;
endmodule
