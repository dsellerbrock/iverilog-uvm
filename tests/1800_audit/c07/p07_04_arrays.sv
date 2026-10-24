module test;
  logic [3:0][7:0] packed_array;
  int unpacked_a[2][3];
  int unpacked_b[2][3];

  initial begin
    packed_array = 32'hdeadbeef;
    if (packed_array[3] !== 8'hde || packed_array[2] !== 8'had
        || packed_array[1] !== 8'hbe || packed_array[0] !== 8'hef
        || packed_array[2][7:4] !== 4'ha
        || packed_array[1 +: 2] !== 16'hadbe)
      $fatal(1, "packed array indexing, slice, or indexed part-select mismatch");

    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        unpacked_a[i][j] = (i + 1) * 10 + j;
    unpacked_b = unpacked_a;
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        if (unpacked_b[i][j] !== unpacked_a[i][j])
          $fatal(1, "unpacked array whole-array copy mismatch");
    unpacked_b[1][2] = 999;
    if (unpacked_b[1][2] != 999 || unpacked_a[1][2] == 999)
      $fatal(1, "unpacked array element update/copy independence mismatch");

    $display("PASS §7.4 packed/unpacked array checks");
    $finish;
  end
endmodule
