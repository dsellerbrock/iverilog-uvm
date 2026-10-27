// IEEE 1800-2017 p. 578 / IEEE 1800-2023 p. 605:
// Specifying the same option more than once in a covergroup definition is an error.
module test_neg_dup_option;
  bit a;
  covergroup cg;
    option.weight = 1;
    option.weight = 2;
    coverpoint a;
  endgroup
  cg c = new;
endmodule
