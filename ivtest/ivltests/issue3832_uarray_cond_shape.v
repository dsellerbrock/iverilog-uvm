module issue3832_uarray_cond_shape;
  logic pred;
  int a[2][3], b[3][2], d[2][3];
  integer other_element[2][3];

  initial begin
    d = pred ? a : b;
    d = pred ? a : other_element;
    d <= 1'b1 ? a : b;
  end
endmodule
