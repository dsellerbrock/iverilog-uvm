module sv_conditional_unpacked_array;
  int a[3] = '{1, 2, 3};
  int b[3] = '{1, 9, 3};
  int d[3];
  integer xa[2] = '{1, 5};
  integer xb[2] = '{1, 7};
  integer xd[2];
  integer ma[0:1][0:1] = '{'{1, 5}, '{3, 9}};
  integer mb[0:1][0:1] = '{'{1, 7}, '{4, 9}};
  integer md[0:1][0:1];
  logic condition;

  initial begin
    condition = 1'b1;
    d = condition ? a : b;
    if (d[0] !== 1 || d[1] !== 2 || d[2] !== 3)
      $fatal(1, "true-condition array selection failed");
    $display("qa D[1]=%0d", d[1]);

    condition = 1'b0;
    d = condition ? a : b;
    if (d[0] !== 1 || d[1] !== 9 || d[2] !== 3)
      $fatal(1, "false-condition array selection failed");

    condition = 1'bx;
    d = condition ? a : b;
    if (d[0] !== 1 || d[1] !== 0 || d[2] !== 3)
      $fatal(1, "ambiguous-condition array merge failed");
    $display("qx int D[0]=%0d D[1]=%0d", d[0], d[1]);

    xd = condition ? xa : xb;
    if (xd[0] !== 1 || xd[1][0] !== 1'b1 || xd[1][1] !== 1'bx
        || xd[1][2] !== 1'b1 || xd[1][31:3] !== 0)
      $fatal(1, "ambiguous-condition 4-state array merge failed");
    $display("qx integer D[1]=%b", xd[1]);

    md = condition ? ma : mb;
    if (md[0][0] !== 1 || md[0][1][1] !== 1'bx
        || md[1][0][2:0] !== 3'bxxx || md[1][0][31:3] !== 0
        || md[1][1] !== 9)
      $fatal(1, "multidimensional ambiguous-condition merge failed");
    $display("qx integer MD[0][1]=%b", md[0][1]);
    $display("PASSED");
  end
endmodule
