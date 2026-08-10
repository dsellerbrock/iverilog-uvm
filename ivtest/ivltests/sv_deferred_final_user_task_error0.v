module deferred_final_user_task_error;
  int value = 23;

  task report_error;
    $error("EXPECTED USER TASK %m VALUE=%0d", value);
  endtask

  initial assert final (0) else report_error();
endmodule
