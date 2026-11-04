module top;
  int array[][2][3] = new[4];
  int i;
  int j;
  int k;

  initial begin
    if (array.size() != 4)
      $fatal(1, "expected dynamic-array size 4, got %0d", array.size());

    for (i = 0; i < 4; i = i + 1)
      for (j = 0; j < 2; j = j + 1)
        for (k = 0; k < 3; k = k + 1)
          if (array[i][j][k] != 0)
            $fatal(1, "element [%0d][%0d][%0d] was not defaulted to 0",
                   i, j, k);

    array[1][1][2] = 23;
    array[3][0][1] = -9;
    if (array[1][1][2] != 23 || array[3][0][1] != -9
        || array[1][1][1] != 0 || array[0][0][0] != 0)
      $fatal(1, "fixed-array elements did not retain independent values");

    $display("PASSED");
  end
endmodule
