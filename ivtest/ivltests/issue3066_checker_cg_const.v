// Issue #3066 control: a const actual is legal for a checker formal that no
// covergroup references, and a covergroup formal shadows a checker formal
// of the same name (IEEE 1800-2017/2023 17.6).
checker c(logic x, logic y);
  covergroup cg;
    cp: coverpoint x;
  endgroup
  covergroup cg2 with function sample(logic y);
    cp: coverpoint y;
  endgroup
  cg inst = new;
  cg2 inst2 = new;
endchecker
module top;
  bit a = 0, b = 1;
  c ci(a, const'(b));
  initial begin #1 $display("PASSED"); end
endmodule
