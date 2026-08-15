module deferred_observed_user_task_actual;
  task automatic report(input int value);
    $display("VALUE=%0d", value);
  endtask

  initial assert #0 (0) else report(7);
endmodule
