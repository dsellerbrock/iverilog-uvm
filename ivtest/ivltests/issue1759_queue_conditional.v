module test;
  int q0[$] = '{1, 2, 3};
  int q1[$] = '{1, 5, 3};
  int q2[$] = '{1, 2};
  int r[$];
  logic c = 1'bx;

  initial begin
    r = c ? q0 : q1;
    if (r.size() != 3 || r[0] != 1 || r[1] != 0 || r[2] != 3)
      $fatal(1, "same-size queue merge failed: %p", r);

    r = c ? q0 : q2;
    if (r.size() != 0)
      $fatal(1, "different-size queue result was not empty: %p", r);

    c = 1'bz;
    r = c ? q0 : q1;
    if (r.size() != 3 || r[0] != 1 || r[1] != 0 || r[2] != 3)
      $fatal(1, "Z-condition queue merge failed: %p", r);

    c = 1'b0;
    r = c ? q0 : q1;
    if (r.size() != 3 || r[1] != 5)
      $fatal(1, "false queue selection failed: %p", r);

    c = 1'b1;
    r = c ? q0 : q1;
    if (r.size() != 3 || r[1] != 2)
      $fatal(1, "true queue selection failed: %p", r);

    $display("PASSED");
  end
endmodule
