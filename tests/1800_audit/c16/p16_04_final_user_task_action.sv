module test;
  task final_report;
    $display("FINAL_TASK_ACTION");
  endtask

  initial begin
    assert final (1'b0) else final_report();
    $display("ACTIVE_REGION_DONE");
    #1 $display("PASSED");
  end
endmodule
