module deferred_final_user_task_nested;
  task leaf;
    $display("LEAF");
  endtask

  task report;
    leaf();
  endtask

  initial assert final (0) else report();
endmodule
