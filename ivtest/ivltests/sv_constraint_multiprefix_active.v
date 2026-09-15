class rank3_reductions;
  rand logic signed [7:0] a[-1:0][3:2][5:7];
  rand logic signed [15:0] result;
  bit fail;

  constraint selected_row_c {
    a[-1][2][5] == -2;
    a[-1][2][6] == 3;
    a[-1][2][7] == 4;
    a[-1][2].sum() == 5;
    a[-1][2].product() == -24;
    a[-1][2].and() == 0;
    a[-1][2].or() == -1;
    a[-1][2].xor() == -7;
    a[-1][2].sum(i) with (i + i.index()) == 23;
    result == a[-1][2].sum();
    fail -> result == 99;
  }
endclass

module test;
  rank3_reductions h;
  int ok;
  initial begin
    h = new;
    foreach (h.a[i,j,k]) h.a[i][j][k] = 8'sd41;
    h.a.rand_mode(0);
    h.a[-1][2].rand_mode(1);
    h.result = 16'sd37;
    ok = h.randomize();
    if (ok != 1 || h.result != 5
        || h.a[-1][2][5] != -2 || h.a[-1][2][6] != 3
        || h.a[-1][2][7] != 4)
      $fatal(1, "rank3 selected row result=%0d values=%0d,%0d,%0d",
             h.result, h.a[-1][2][5], h.a[-1][2][6], h.a[-1][2][7]);
    if (h.a[0][3][5] != 41 || h.a[-1][3][7] != 41
        || h.a[0][2][6] != 41)
      $fatal(1, "rank3 inactive neighboring leaves changed");
    h.fail = 1; h.result = 16'sd53;
    ok = h.randomize();
    if (ok != 0 || h.result != 53
        || h.a[-1][2][5] != -2 || h.a[-1][2][6] != 3
        || h.a[-1][2][7] != 4)
      $fatal(1, "rank3 failed solve rollback ok=%0d result=%0d", ok, h.result);
    $display("PASSED");
  end
endmodule
