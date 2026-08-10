module deferred_final_user_task_actual;
  task report(input int value);
    $display("VALUE=%0d", value);
  endtask

  initial assert final (0) else report(7);
endmodule
