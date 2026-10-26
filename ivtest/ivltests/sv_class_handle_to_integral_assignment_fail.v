module sv_class_handle_to_integral_assignment_fail;
  class c; endclass
  c object;
  logic q;

  initial q = object;
endmodule
