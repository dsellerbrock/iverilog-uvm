// A direct scoped use of a class with a parameter port list names the generic
// class. It is not shorthand for the default specialization C#().
module sv_param_class_bare_static_function_fail;
  class wrapper #(type IMP = int);
    static function int call;
      return 1;
    endfunction
  endclass

  initial begin
    int value;
    value = wrapper::call();
  end
endmodule
