// A recognized class-scoped l-value must diagnose an absent or non-static
// property directly. A nearer non-class typedef must also hide an outer class.
module sv_param_class_scoped_static_lvalue_invalid_fail;
  class wrapper #(int VALUE = 13);
    static int value = VALUE;
    int instance_value;
  endclass

  initial begin
    wrapper#()::missing = 1;
    wrapper#()::instance_value = 2;
  end

  initial begin : typedef_shadow
    typedef int wrapper;
    wrapper::value = 3;
  end
endmodule
