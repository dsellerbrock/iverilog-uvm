// Basic DPI-C test: import and call C functions
module top;
  import "DPI-C" pure function int c_add(int a, int b);
  import "DPI-C" pure function int c_mul(int a, int b);
  import "DPI-C" pure function int c_factorial(int n);

  int pass_count;

  initial begin
    pass_count = 0;

    if (c_add(3, 4) == 7) pass_count++;
    if (c_add(-5, 10) == 5) pass_count++;
    if (c_mul(6, 7) == 42) pass_count++;
    if (c_mul(0, 100) == 0) pass_count++;
    if (c_factorial(5) == 120) pass_count++;
    if (c_factorial(1) == 1) pass_count++;

    if (pass_count == 6)
      $display("DPI BASIC TEST: PASS (%0d/6)", pass_count);
    else
      $display("DPI BASIC TEST: FAIL (%0d/6)", pass_count);

    $finish;
  end
endmodule
