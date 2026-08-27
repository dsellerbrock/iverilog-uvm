// IEEE 1800-2017/2023 10.9.1: one associative-array assignment pattern
// cannot contain more than one default key.
module main;
  int values[string] = '{default:3, "live":4, default:5};
endmodule
