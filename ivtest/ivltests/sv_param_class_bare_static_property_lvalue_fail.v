// A parameterized generic class name requires an explicit specialization on
// the left of :: even when the static property is an assignment l-value.
module sv_param_class_bare_static_property_lvalue_fail;
  class wrapper #(int VALUE = 13);
    static int value = VALUE;
  endclass

  initial begin
    wrapper::value = 23;
  end
endmodule
