// These fixed-array locator forms are legal. Keep them loud until the loop
// can iterate subarrays and carry nonintegral element values faithfully.
module multidimensional_fixed;
  int values[1:0][1:0];

  initial
    $display("%p", values.find_last with (item[0] > 0));
endmodule

module nonintegral_fixed;
  string values[1:0];
  string found[$];

  initial
    found = values.find_last with (item == "match");
endmodule
