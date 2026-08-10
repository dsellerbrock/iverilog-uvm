module deferred_final_user_task_mutating;
  int value;

  task report;
    value = 1;
  endtask

  initial assert final (0) else report();
endmodule
