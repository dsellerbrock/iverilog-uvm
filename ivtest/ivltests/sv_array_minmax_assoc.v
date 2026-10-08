// IEEE 1800-2017/2023 7.12.1: min/max operate on associative-array values.
module sv_array_minmax_assoc;
  int by_int[int];
  int by_string[string];
  int result[$];

  initial begin
    by_int[8] = 9;
    by_int[1] = 4;
    by_int[5] = 7;
    by_int[9] = 4;
    by_int[10] = 9;
    by_string["z"] = 9;
    by_string["a"] = 4;
    by_string["m"] = 7;

    result = by_int.min();
    if (result.size() != 1 || result[0] != 4)
      $fatal(1, "integer-key associative min failed");
    result = by_int.max;
    if (result.size() != 1 || result[0] != 9)
      $fatal(1, "integer-key associative max failed");
    result = by_string.min with (item * -1);
    if (result.size() != 1 || result[0] != 9)
      $fatal(1, "associative min with expression failed");
    result = by_string.max with (item);
    if (result.size() != 1 || result[0] != 9)
      $fatal(1, "string-key associative max with failed");

    by_int.delete();
    result = by_int.min;
    if (result.size() != 0)
      $fatal(1, "empty associative min result was not empty");

    $display("PASSED");
  end
endmodule
