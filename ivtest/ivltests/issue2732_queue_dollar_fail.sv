// Issue #2732: `$' is the last index only inside a queue index or slice
// bound (IEEE 1800-2017/2023 7.10.1); elsewhere it is an error.
module test;
  int x;
  initial x = $ + 1;
endmodule
