// This fixed-array locator form is legal (IEEE 1800-2017/2023 7.12.1) but
// unimplemented: the loop cannot yet iterate subarrays for a
// multidimensional fixed array. Keep it loud until that lands.
//
// The sibling "nonintegral fixed array" case that used to live in this
// same file (`values.find_last with (item == "match")` on a plain
// `string values[1:0]`) is now correctly implemented (L36) -- see
// sv_locator_fixed_nonintegral.v for its positive-path coverage.
module multidimensional_fixed;
  int values[1:0][1:0];

  initial
    $display("%p", values.find_last with (item[0] > 0));
endmodule
