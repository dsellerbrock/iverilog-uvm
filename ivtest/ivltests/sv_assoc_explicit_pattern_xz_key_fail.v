// IEEE 1800-2017/2023 7.8.1, 7.8.4, and 10.9.1: an explicit integral
// associative-array assignment-pattern index cannot contain unknown bits.
// Preserve both X and Z through contextual sizing so neither becomes index 0.
module main;
  typedef logic [3:0] key_t;
  int values[key_t] = '{4'b1x0z:6};
endmodule
