module issue1801_task_process_fork_control;
  int wait_prior_done;
  int wait_inner_done;
  int disable_prior_ran;
  int disable_checked;

  task automatic wait_in_task;
    fork
      #3 wait_inner_done = 1;
    join_none
    wait fork;
    if ($time != 7 || !wait_prior_done || !wait_inner_done)
      $fatal(1, "wait fork in task missed a caller child or returned early");
    $display("PASS wait fork in task includes caller children");
  endtask

  task automatic disable_in_task;
    disable fork;
  endtask

  initial begin
    fork
      #7 wait_prior_done = 1;
    join_none
    wait_in_task();
    if (!disable_checked)
      $fatal(1, "disable fork test did not complete");
    $display("PASSED");
    $finish;
  end

  initial begin
    fork
      #5 disable_prior_ran = 1;
    join_none
    disable_in_task();
    #6;
    if (disable_prior_ran)
      $fatal(1, "disable fork in task left a caller child running");
    disable_checked = 1;
    $display("PASS disable fork in task includes caller children");
  end
endmodule
