// An exact non-class typedef shadows an outer class of the same name for
// every scoped static dispatch form. No resolver may recover the hidden class
// by spelling after the typedef has resolved successfully.
module sv_class_typedef_scoped_static_shadow_fail;
  class selected_type;
    static int value = 1;

    static function int read_value;
      return value;
    endfunction

    static task write_value;
      value = 2;
    endtask
  endclass

  class holder;
    typedef int selected_type;

    static function int call_function;
      return selected_type::read_value();
    endfunction

    static function int read_property;
      return selected_type::value;
    endfunction

    static task call_task;
      selected_type::write_value();
    endtask
  endclass

  initial begin
    int sink;
    sink = holder::call_function();
    sink = holder::read_property();
    holder::call_task();
  end
endmodule
