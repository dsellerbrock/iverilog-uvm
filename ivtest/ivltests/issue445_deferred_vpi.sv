module issue445_deferred_vpi;
  initial begin
    $setup_issue445_deferred_vpi;

    begin : canceled
      assert #0 (1'b1) $display("CANCELED_ACTION");
      $assertkill(0, issue445_deferred_vpi);
      $asserton(0, issue445_deferred_vpi);
    end

    assert #0 (1'b1) $display("OBSERVED_PASS_ACTION");
    else $display("OBSERVED_PASS_FAIL_ACTION");
    assert #0 (1'b0) $display("OBSERVED_FAIL_PASS_ACTION");
    else $display("OBSERVED_FAIL_ACTION");
    assert final (1'b1) $display("FINAL_PASS_ACTION");
    else $display("FINAL_PASS_FAIL_ACTION");
    assert final (1'b0) $display("FINAL_FAIL_PASS_ACTION");
    else $display("FINAL_FAIL_ACTION");

    $assertoff(0, issue445_deferred_vpi);
    assert #0 (1'b1) $display("DISABLED_ACTION");
    else $display("DISABLED_FAIL_ACTION");
    $asserton(0, issue445_deferred_vpi);

    assert #0 (1'b1) deferred_task_action();
    else $display("TASK_FAIL_ACTION");

    #1 $check_issue445_deferred_vpi;
    $finish;
  end

  task deferred_task_action;
    $display("OBSERVED_TASK_ACTION");
  endtask
endmodule
