// IEEE 1800-2017/2023 §18.13.1: $urandom accepts at most one seed argument.
module test;
  int unsigned value;
  initial value = $urandom(1, 2);
endmodule
