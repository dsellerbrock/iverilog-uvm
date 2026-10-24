module sv_covergroup_cross_foreign_fail;
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
