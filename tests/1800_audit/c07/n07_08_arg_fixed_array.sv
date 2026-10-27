module n07_08_arg_fixed_array;
  int a[string];
  function automatic void wrong_shape(int x[4]); endfunction
  initial wrong_shape(a);
endmodule
