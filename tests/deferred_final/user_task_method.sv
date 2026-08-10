class deferred_final_reporter;
  task report;
    $display("METHOD");
  endtask
endclass

module deferred_final_user_task_method;
  deferred_final_reporter reporter;

  initial begin
    reporter = new;
    assert final (0) else reporter.report();
  end
endmodule
