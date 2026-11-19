module issue3832_uarray_cond_dead;
  int a[0:1], b[2:4], d[0:1];
  initial d = 1 ? a : b;
endmodule
