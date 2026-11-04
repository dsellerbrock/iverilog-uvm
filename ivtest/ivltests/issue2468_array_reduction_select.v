module issue2468_array_reduction_select;
  int a[1:0][3:2][-1:1];
  initial begin
    foreach (a[i, j, l]) a[i][j][l] = i * 100 + j * 10 + l;
    if (a[1][2].sum() != 360)
      $fatal(1, "selected row sum=%0d", a[1][2].sum());
    if (a[1][2].product() != 1727880)
      $fatal(1, "selected row product=%0d", a[1][2].product());
    if (a[0][3].sum() with (item.index) != 0)
      $fatal(1, "selected row index sum=%0d",
             a[0][3].sum() with (item.index));
    $display("360 1727880 0");
  end
endmodule
