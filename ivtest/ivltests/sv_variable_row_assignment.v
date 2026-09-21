module main;
  int a[5:7][2:0];
  int b[5:7][2:0];
  int down[3:1][4:2];
  int up[1:3][2:4];
  int keep[0:1][0:2];
  integer i, j;
  int selector_calls;

  function automatic int pick_row;
    selector_calls = selector_calls + 1;
    pick_row = 6;
  endfunction

  initial begin
    a[5] = '{10, 11, 12};
    a[6] = '{20, 21, 22};
    a[7] = '{30, 31, 32};
    b[5] = '{50, 51, 52};
    b[6] = '{60, 61, 62};
    b[7] = '{70, 71, 72};

    // A run-time selected blocking row copy keeps the selected row shape.
    i = 6;
    j = 7;
    a[i] = b[j];
    if (a[6][2] != 70 || a[6][1] != 71 || a[6][0] != 72)
      $fatal(1, "blocking variable row copy failed");

    // The l-value selector and all RHS row values are captured before the
    // following assignments change either selector or the source row.
    i = 5;
    j = 7;
    a[i] <= b[j];
    i = 6;
    j = 5;
    b[7] = '{700, 701, 702};
    #1;
    if (a[5][2] != 70 || a[5][1] != 71 || a[5][0] != 72)
      $fatal(1, "NBA row selector or RHS was not captured");
    if (a[6][2] != 70 || a[6][1] != 71 || a[6][0] != 72)
      $fatal(1, "NBA wrote the changed destination row");

    // This is the OpenTitan reset spelling: a variable selected row receives
    // a default assignment pattern in the NBA region.
    i = 7;
    a[i] <= '{default:0};
    i = 5;
    #1;
    if (a[7][2] != 0 || a[7][1] != 0 || a[7][0] != 0)
      $fatal(1, "NBA default row pattern failed");
    if (a[5][2] != 70 || a[5][1] != 71 || a[5][0] != 72)
      $fatal(1, "NBA default pattern did not capture its row selector");

    // Each selector expression is evaluated once, including the pattern path.
    selector_calls = 0;
    a[pick_row()] = b[5];
    if (selector_calls != 1 || a[6][2] != 50)
      $fatal(1, "blocking row selector was not evaluated once");
    selector_calls = 0;
    a[pick_row()] <= '{default:9};
    if (selector_calls != 1) $fatal(1, "NBA pattern selector was reevaluated");
    #1;
    if (a[6][2] != 9 || a[6][1] != 9 || a[6][0] != 9)
      $fatal(1, "NBA pattern selector chose the wrong row");

    // Opposite directions use declared left-to-right correspondence.
    up[3] = '{101, 102, 103};
    i = 2;
    down[i] = up[3];
    if (down[2][4] != 101 || down[2][3] != 102 || down[2][2] != 103)
      $fatal(1, "descending row correspondence failed");

    // A bad selected row does not write any neighboring row.
    keep[0] = '{201, 202, 203};
    keep[1] = '{211, 212, 213};
    i = -1;
    keep[i] = b[5];
    i = 2;
    keep[i] = b[5];
    i = 'x;
    keep[i] = b[5];
    i = 'x;
    keep[i] <= '{default:0};
    #1;
    if (keep[0][0] != 201 || keep[0][2] != 203
        || keep[1][0] != 211 || keep[1][2] != 213)
      $fatal(1, "out-of-range row selector wrote data");

    // Existing constant-prefix behavior remains available.
    a[6] = b[5];
    if (a[6][2] != 50 || a[6][1] != 51 || a[6][0] != 52)
      $fatal(1, "constant row copy regressed");
    $display("PASSED");
  end
endmodule
