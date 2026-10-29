module top;
  int array[][2][3] = new[4];

  initial begin
    if (array.size() != 4)
      $fatal(1, "dynamic array size: expected 4, got %0d", array.size());
    if (array[0][0][0] != 0 || array[3][1][2] != 0)
      $fatal(1, "fixed inner elements were not initialized to zero");
    $display("PASS: dynamic array with multiple fixed inner dimensions");
    $display("PASSED");
  end
endmodule
