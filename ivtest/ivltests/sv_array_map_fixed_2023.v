module sv_array_map_fixed_2023;
  int source[5:3] = '{50, 40, 30};
  int mapped[5:3];
  string fixed_strings[5:3];
  int matrix[1:0][2:1];
  int matrix_sums[1:0];
  int matrix_copy[1:0][2:1];

  initial begin
    matrix[1][2] = 1;
    matrix[1][1] = 2;
    matrix[0][2] = 3;
    matrix[0][1] = 4;

    mapped = source.map(value) with (value + value.index);
    if ($left(mapped) != 5 || $right(mapped) != 3
        || mapped[5] != 55 || mapped[4] != 44 || mapped[3] != 33)
      $fatal(1, "fixed map range/values: %p", mapped);

    fixed_strings = source.map(value) with ($sformatf("n%0d", value));
    if ($left(fixed_strings) != 5 || $right(fixed_strings) != 3
        || fixed_strings[5] != "n50" || fixed_strings[4] != "n40"
        || fixed_strings[3] != "n30")
      $fatal(1, "fixed string map range/values: %p", fixed_strings);

    matrix_sums = matrix.map(row) with (row.sum());
    if ($left(matrix_sums) != 1 || $right(matrix_sums) != 0
        || matrix_sums[1] != 3 || matrix_sums[0] != 7)
      $fatal(1, "fixed multidimensional map range/values: %p", matrix_sums);

    matrix_copy = matrix.map(row) with (row);
    if ($left(matrix_copy) != 1 || $right(matrix_copy) != 0
        || matrix_copy[1][2] != 1 || matrix_copy[1][1] != 2
        || matrix_copy[0][2] != 3 || matrix_copy[0][1] != 4)
      $fatal(1, "fixed array-valued map result: %p", matrix_copy);
    $display("PASSED");
  end
endmodule
