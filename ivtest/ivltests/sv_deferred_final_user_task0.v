module deferred_final_user_task;
  int value = 1;
  bit cancel;

  task report_static;
    begin
      $display("STATIC %m VALUE=%0d", value);
    end
  endtask

  task automatic report_auto;
    $display("AUTO %m VALUE=%0d", value);
  endtask

  // Re-entering this source assertion first pins and then cancels its action.
  task arm_cancel;
    assert final (cancel) else report_static();
  endtask

  initial begin
    assert final (0) else report_static();
    assert final (0) else report_auto();
    cancel = 0;
    arm_cancel();
    cancel = 1;
    arm_cancel();
    value <= 42;
    $finish(0);
  end
endmodule
