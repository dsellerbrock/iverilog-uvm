// The generic class scope cannot be used directly for a static task call.
module sv_param_class_bare_static_task_fail;
  class wrapper #(type IMP = int);
    static task call;
      $display("UNREACHABLE");
    endtask
  endclass

  initial wrapper::call();
endmodule
