module n12_07_foreach_too_many_indices;
  int a [1:0];
  initial foreach (a[i, j]) $display("%0d %0d", i, j);
endmodule
