module issue1471_multidim_unpacked_slice;
  int matrix[0:1][0:2];
  int row_slice[1:2];
  int dynamic_row_slice[1:2];

  int cube[0:1][0:3][0:2];
  int strided_slice[1:2];
  int indexed_slice[1:2];
  int reversed_slice[2:1];

  int row;
  int start;
  integer i, j, k;

  initial begin
    matrix[0][0] = 1;
    matrix[0][1] = 2;
    matrix[0][2] = 3;
    matrix[1][0] = 11;
    matrix[1][1] = 12;
    matrix[1][2] = 13;

    row_slice = matrix[0][1:2];
    if (row_slice[1] !== 2 || row_slice[2] !== 3)
      $fatal(1, "constant-prefix slice");

    row = 1;
    dynamic_row_slice = matrix[row][1:2];
    if (dynamic_row_slice[1] !== 12 || dynamic_row_slice[2] !== 13)
      $fatal(1, "variable-prefix slice");

    for (i = 0; i < 2; i = i + 1)
      for (j = 0; j < 4; j = j + 1)
        for (k = 0; k < 3; k = k + 1)
          cube[i][j][k] = i * 100 + j * 10 + k;

    strided_slice = cube[1][1:2][2];
    if (strided_slice[1] !== 112 || strided_slice[2] !== 122)
      $fatal(1, "strided dimension slice");

    start = 1;
    indexed_slice = cube[row][start +: 2][2];
    if (indexed_slice[1] !== 112 || indexed_slice[2] !== 122)
      $fatal(1, "variable-position strided slice");

    row = 0;
    start = 3;
    indexed_slice = cube[row][start +: 2][2];
    if (indexed_slice[1] !== 32 || indexed_slice[2] !== 0)
      $fatal(1, "out-of-range sliced element");

    reversed_slice = cube[1][1:2][0];
    if (reversed_slice[2] !== 110 || reversed_slice[1] !== 120)
      $fatal(1, "slice direction correspondence");

    $display("ISSUE1471 multidimensional slice pass");
    $display("PASSED");
  end
endmodule
