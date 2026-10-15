typedef union soft packed {
  bit [7:0] bits;
  string text;
} invalid_t;

module test;
  invalid_t value;
endmodule
