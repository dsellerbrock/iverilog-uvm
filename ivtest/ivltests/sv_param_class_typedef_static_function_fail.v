// A bare class typedef is a concrete use and therefore denotes wrapper#().
// The invalid method call in the default type binding must be diagnosed.
module sv_param_class_typedef_static_function_fail;
  class wrapper #(type IMP = int);
    static function int call;
      IMP imp;
      return imp.no_such_method();
    endfunction
  endclass

  typedef wrapper default_wrapper;
  initial begin
    int value;
    value = default_wrapper::call();
  end
endmodule
