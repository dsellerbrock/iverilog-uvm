module issue1480_real_assoc_index_fail;
  int wildcard_values[*];
  int typed_values[int];
  real wildcard_key = 3.5;
  shortreal typed_key = 2.75;

  initial begin
    wildcard_values[wildcard_key] = 8;
    typed_values[typed_key] = 17;
  end
endmodule
