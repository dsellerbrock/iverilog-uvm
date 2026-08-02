// A typedef enum declared directly in a task/function must have its
// literals elaborated in that subroutine scope. This also pins enum name()
// reflection and guards against duplicate/empty VVP enum typespecs.
module subroutine_local_enum_test;
  task automatic check_task(output bit ok);
    typedef enum int {MSG_IDLE, MSG_START, MSG_RUN} message_state_t;
    message_state_t state = MSG_RUN;
    ok = state == MSG_RUN && state.name() == "MSG_RUN";
  endtask

  function automatic bit check_function();
    typedef enum logic [1:0] {FN_ZERO, FN_ONE, FN_TWO} function_state_t;
    function_state_t state = FN_TWO;
    return state == FN_TWO && state.name() == "FN_TWO";
  endfunction

  initial begin
    bit task_ok;
    check_task(task_ok);
    if (task_ok && check_function())
      $display("PASS subroutine_local_enum_test");
    else
      $display("FAIL subroutine_local_enum_test");
    $finish;
  end
endmodule
