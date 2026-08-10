// Task lookup through a concretely defaulted type parameter must not inherit
// the generic template master's deferred receiver treatment.
module sv_typeparam_receiver_omitted_default_task_fail;
  class task_wrapper #(type IMP = int);
    IMP m_imp;

    task forward(input int value);
      m_imp.no_such_task(value);
    endtask
  endclass

  initial begin
    task_wrapper bad;

    bad = new;
    bad.forward(1);
  end
endmodule
