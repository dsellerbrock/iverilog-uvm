module n10_10_pattern_array_item_type;
  int A[3];
  int B[2];
  initial begin
    B = '{3, 4};
    A = '{B, 5};
  end
endmodule
