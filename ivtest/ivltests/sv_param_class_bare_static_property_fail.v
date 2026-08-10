// A direct static-property reference also requires an explicit specialization.
module sv_param_class_bare_static_property_fail;
  class wrapper #(int VALUE = 13);
    static int value = VALUE;
  endclass

  initial $display("%0d", wrapper::value);
endmodule
