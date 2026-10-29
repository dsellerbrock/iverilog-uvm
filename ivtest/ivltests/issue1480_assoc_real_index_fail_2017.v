module top;
  int wildcard_real_values[*];
  real real_key = 3.5;
  int typed_real_values[int];
  real typed_real_key = 2.75;
  int wildcard_shortreal_values[*];
  shortreal shortreal_key = 3.5;
  int typed_shortreal_values[int];
  shortreal typed_shortreal_key = 2.75;

  initial begin
    wildcard_real_values[real_key] = 8;
    typed_real_values[typed_real_key] = 17;
    wildcard_shortreal_values[shortreal_key] = 8;
    typed_shortreal_values[typed_shortreal_key] = 17;
  end
endmodule
