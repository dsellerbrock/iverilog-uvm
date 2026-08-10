// A typedef of a bare parameterized class invokes the default specialization
// for a scoped static task just as it does for an object declaration.
module sv_param_class_typedef_static_task_fail;
  class wrapper #(type IMP = int);
    static task call;
      IMP imp;
      imp.no_such_task();
    endtask
  endclass

  typedef wrapper default_wrapper;
  initial default_wrapper::call();
endmodule
