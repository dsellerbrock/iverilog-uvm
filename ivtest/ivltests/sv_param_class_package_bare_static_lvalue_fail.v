package bare_static_lvalue_pkg;
  class wrapper #(int VALUE = 13);
    static int value = VALUE;
  endclass
endpackage

module sv_param_class_package_bare_static_lvalue_fail;
  initial begin
    bare_static_lvalue_pkg::wrapper::value = 23;
  end
endmodule
