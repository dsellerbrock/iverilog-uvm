// IEEE 1800-2017 §18.12 / IEEE 1800-2023 §18.12: the argument must be a variable.
module test;
  int a;
  initial void'(std::randomize(a + 1));
endmodule
