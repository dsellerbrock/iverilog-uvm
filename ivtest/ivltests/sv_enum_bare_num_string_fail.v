module test;
  typedef enum int { Red, Blue } color_t;
  color_t value;
  string label;
  initial label = {value.num, "_invalid"};
endmodule
