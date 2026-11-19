module issue3832_uarray_cond;
  logic pred;
  int a[0:1] = '{1, 5};
  int b[2:3] = '{1, 7};
  int d[0:1];
  int rev[-1:-2];

  int ma[4:5][-1:-3] = '{'{11, 12, 13}, '{21, 22, 23}};
  int mb[8:7][2:4] = '{'{11, 32, 13}, '{41, 22, 43}};
  int md[-4:-5][6:4];

  initial begin
    pred = 1'bx;
    d = pred ? a : b;
    if (d[0] !== 1 || d[1] !== 0)
      $fatal(1, "shifted bounds under an ambiguous predicate");

    pred = 1'b1;
    rev = pred ? a : b;
    if (rev[-1] !== 1 || rev[-2] !== 5)
      $fatal(1, "true selection into a descending destination");

    pred = 1'b0;
    rev = pred ? a : b;
    if (rev[-1] !== 1 || rev[-2] !== 7)
      $fatal(1, "false selection into a descending destination");

    pred = 1'bx;
    md = pred ? ma : mb;
    if (md[-4][6] !== 11 || md[-4][5] !== 0 || md[-4][4] !== 13 ||
        md[-5][6] !== 0  || md[-5][5] !== 22 || md[-5][4] !== 0)
      $fatal(1, "ambiguous merge across mixed directions");

    pred = 1'b1;
    md = pred ? ma : mb;
    if (md[-4][6] !== 11 || md[-4][5] !== 12 || md[-4][4] !== 13 ||
        md[-5][6] !== 21 || md[-5][5] !== 22 || md[-5][4] !== 23)
      $fatal(1, "true selection across mixed directions");

    pred = 1'b0;
    md = pred ? ma : mb;
    if (md[-4][6] !== 11 || md[-4][5] !== 32 || md[-4][4] !== 13 ||
        md[-5][6] !== 41 || md[-5][5] !== 22 || md[-5][4] !== 43)
      $fatal(1, "false selection across mixed directions");

    rev = 1 ? a : b;
    if (rev[-1] !== 1 || rev[-2] !== 5)
      $fatal(1, "known predicate in the direct array copy");

    md[-4][5] = -1;
    md <= 0 ? ma : mb;
    if (md[-4][5] !== -1)
      $fatal(1, "NBA updated the array immediately");
    #1;
    if (md[-4][6] !== 11 || md[-4][5] !== 32 || md[-4][4] !== 13 ||
        md[-5][6] !== 41 || md[-5][5] !== 22 || md[-5][4] !== 43)
      $fatal(1, "known predicate in typed NBA elaboration");

    $display("PASSED");
  end
endmodule
