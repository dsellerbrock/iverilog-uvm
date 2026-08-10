module deferred_final_user_task_timed;
  task report;
    #0 $display("TIMED");
  endtask

  initial assert final (0) else report();
endmodule
