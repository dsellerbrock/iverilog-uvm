// IEEE 1800-2017/2023 7.8.4 and 7.9.11: an enum-indexed associative-array
// literal requires an integral key; a string literal is not implicitly
// convertible to that index type.
module main;
  typedef enum logic [1:0] { KEY_ZERO, KEY_ONE } key_e;
  int values[key_e] = '{"not-an-enum":6};
endmodule
