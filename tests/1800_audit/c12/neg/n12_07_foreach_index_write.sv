module n12_07_foreach_index_write;
  int a [1:0];
  initial foreach (a[i]) i = 1;
endmodule
