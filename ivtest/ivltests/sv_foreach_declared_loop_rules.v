module foreach_too_many_loop_variables;
  int a[3];
  initial foreach (a[i, j]) ;
endmodule

module foreach_same_name_loop_variable;
  int a[3];
  initial foreach (a[a]) ;
endmodule

module foreach_loop_variable_write;
  int a[1:0];
  initial foreach (a[i]) i = 1;
endmodule

module foreach_explicit_packed_dimensions;
  logic [3:0] a[1:0];
  initial foreach (a[i, j]) ;
endmodule

module foreach_builtin_element_dimension;
  int a[3];
  initial foreach (a[i]) ;
endmodule
