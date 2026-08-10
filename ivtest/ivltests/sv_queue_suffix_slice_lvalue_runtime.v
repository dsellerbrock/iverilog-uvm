// Runtime-invalid bounds and size mismatches diagnose and leave the complete
// destination queue unchanged. No failing case may partially write a suffix.
module main;
  bit failed;
  int q[$], rhs[$];
  integer lo;

  task check_unchanged(string label);
    if (!(q.size() == 4 && q[0] == 1 && q[1] == 2 &&
          q[2] == 3 && q[3] == 4)) begin
      $display("FAILED -- %0s", label);
      failed = 1;
    end
  endtask

  initial begin
    q = {1, 2, 3, 4};

    rhs = {8, 9};
    lo = 1;
    q[lo:$] = rhs;
    check_unchanged("short source");

    rhs = {8, 9, 10, 11};
    lo = 2;
    q[lo:$] = rhs;
    check_unchanged("long source");

    rhs = {8, 9, 10, 11};
    lo = -1;
    q[lo:$] = rhs;
    check_unchanged("negative lower bound");

    rhs = {8};
    lo = 99;
    q[lo:$] = rhs;
    check_unchanged("past-last lower bound");

    lo = 'x;
    q[lo:$] = rhs;
    check_unchanged("undefined lower bound");

    if (failed)
      $finish(1);
    $display("PASSED");
  end
endmodule
