// IEEE 1800-2017/2023 10.9.1: one associative-array index cannot be
// specified more than once in one assignment pattern.
module main;
  int values[string] = '{"same":1, "same":2};
endmodule
