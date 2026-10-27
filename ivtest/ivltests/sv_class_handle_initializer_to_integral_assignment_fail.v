module sv_class_handle_initializer_to_integral_assignment_fail;
  class c; endclass
  c object;
  logic q = object;
endmodule
