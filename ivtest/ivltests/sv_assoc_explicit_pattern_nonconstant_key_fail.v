// IEEE 1800-2017/2023 7.9.11 and 10.9.1: an explicit associative-array
// assignment-pattern index must be a constant expression in the declared
// index type. A live variable is not converted into a run-time map key.
module main;
  int live_key = 2;
  int values[int] = '{live_key:6};
endmodule
