// Issue #3066: IEEE 1800-2017/2023 17.6 -- "it shall be an error if a formal
// argument referenced by a covergroup has a const actual argument."
checker c(logic x);
  covergroup cg;
    cp: coverpoint x;
  endgroup
  cg inst = new;
endchecker
module top;
  bit a = 0;
  c ci(const'(a));
endmodule
