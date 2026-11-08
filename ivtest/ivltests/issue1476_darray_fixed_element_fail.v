// Whole fixed unpacked-array elements of a dynamic array, and selecting
// part of a multi-dimensional element, are not supported yet; they are
// reported instead of crashing the code generator.
module top;
  int d[][2];
  int m[][2][3];
  int x[2];
  int y;
  initial begin
    d = new[2];
    m = new[2];
    d[1] = x;
    x = d[0];
    y = m[1][0];
  end
endmodule
