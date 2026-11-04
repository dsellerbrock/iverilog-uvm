module top;
  bit a = 1;

  task check_task;
    task_good: assert (a);
  endtask

  initial begin
    #1;
    good: assert (a) else $display("ASSERT_FAIL_ONE");
    check_task();
    a = 0;
    bad: assert (a) else $display("ASSERT_FAIL_TWO");
    $check_immediate_assertion_callbacks();
    #1 $finish;
  end
endmodule
