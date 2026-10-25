module sv_class_handle_property_to_integral_assignment_fail;
  class c; endclass
  class holder; c object; endclass
  holder h;
  logic q;
  initial q = h.object;
endmodule
