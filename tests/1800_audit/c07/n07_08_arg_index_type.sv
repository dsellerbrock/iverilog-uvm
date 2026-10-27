module n07_08_arg_index_type;
  int a[string];
  function automatic void wrong_index(int x[int]); endfunction
  initial wrong_index(a);
endmodule
