// G30: DPI open-array surface (svdpi.h)
// Tests that C code can include svdpi.h and use the open-array API
// to iterate over array data supplied from the SV side.
module top;
  // C function receives five int args (the five elements of a SV unpacked
  // int[5] array); it assembles them into a local C array, wraps it in an
  // svOpenArrayHandle via the Icarus svdpi_new_array() extension, and
  // iterates using svGetArrElemPtr1 / svLow / svHigh / svSize / svDimensions.
  import "DPI-C" pure function int c_test_open_array(
      int a0, int a1, int a2, int a3, int a4);

  // C function that tests 2D array iteration
  import "DPI-C" pure function int c_test_open_array_2d(
      int r0c0, int r0c1, int r1c0, int r1c1, int r2c0, int r2c1);

  int result;
  int result2d;

  initial begin
    // 1D test: SV unpacked int[0:4] = '{10, 20, 30, 40, 50}
    result = c_test_open_array(10, 20, 30, 40, 50);

    // 2D test: [0:2][0:1] (3 rows, 2 cols)
    result2d = c_test_open_array_2d(1, 2, 3, 4, 5, 6);

    if (result == 1 && result2d == 1)
      $display("G30 DPI OPEN ARRAY: PASS");
    else
      $display("G30 DPI OPEN ARRAY: FAIL (1d=%0d 2d=%0d)", result, result2d);

    $finish;
  end
endmodule
