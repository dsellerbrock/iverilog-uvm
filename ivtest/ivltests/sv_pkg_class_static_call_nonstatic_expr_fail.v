package pkg_class_static_call_nonstatic_expr_pkg;
  class call_target;
    function int m();
      return 1;
    endfunction
  endclass
endpackage

module sv_pkg_class_static_call_nonstatic_expr_fail;
  int value;
  initial value = pkg_class_static_call_nonstatic_expr_pkg::call_target::m();
endmodule
