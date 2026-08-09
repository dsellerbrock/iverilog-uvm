// Associative-array locator methods are legal, but find_last_index must
// return the actual associative index type. Keep this residual loud until
// keyed iteration and typed key results are implemented.
module main;
  int by_name[string];
  string indexes[$];

  initial begin
    by_name["a"] = 1;
    by_name["b"] = 2;
    indexes = by_name.find_last_index with (item > 0);
  end
endmodule
