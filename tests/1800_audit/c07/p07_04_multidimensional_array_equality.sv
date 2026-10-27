module test;
  int left[2][3];
  int right[2][3];

  initial begin
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 3; j++)
        begin
          left[i][j] = (i + 1) * 10 + j;
          right[i][j] = (i + 1) * 10 + j;
        end
    if (left != right)
      $fatal(1, "equal two-dimensional unpacked arrays compared unequal");
    right[1][2] = 99;
    if (left == right)
      $fatal(1, "different two-dimensional unpacked arrays compared equal");
    $display("PASS two-dimensional unpacked array equality");
    $finish;
  end
endmodule
