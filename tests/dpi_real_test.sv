// DPI-C test: import C functions with real return type
module top;
  import "DPI-C" pure function real c_sqrt(real x);
  import "DPI-C" pure function real c_pow(real x, real y);

  int pass_count;

  initial begin
    pass_count = 0;
    if ($abs(c_sqrt(4.0) - 2.0) < 1e-6) pass_count++;
    if ($abs(c_sqrt(9.0) - 3.0) < 1e-6) pass_count++;
    if ($abs(c_pow(2.0, 10.0) - 1024.0) < 1e-6) pass_count++;
    if ($abs(c_pow(3.0, 3.0) - 27.0) < 1e-6) pass_count++;

    if (pass_count == 4)
      $display("DPI REAL TEST: PASS (%0d/4)", pass_count);
    else
      $display("DPI REAL TEST: FAIL (%0d/4)", pass_count);
    $finish;
  end
endmodule
