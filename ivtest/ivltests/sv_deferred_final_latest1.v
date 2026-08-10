module t;
  task automatic latest(input bit ok);
    assert final (ok) $display("LATEST_PASS");
      else $display("LATEST_FAIL");
  endtask

  task automatic cancel_fail(input bit ok);
    assert final (ok) else $display("CANCEL_FAIL");
  endtask

  task automatic cancel_pass(input bit ok);
    assert final (ok) $display("CANCEL_PASS"); else ;
  endtask

  task automatic first_source(input bit ok);
    assert final (ok) $display("FIRST_PASS");
      else $display("FIRST_FAIL");
  endtask

  task automatic second_source;
    assert final (0) else $display("SECOND");
  endtask

  initial begin
    // One pending result per source and logical process: the latest arm wins.
    latest(0);
    latest(1);
    latest(0);

    // A later omitted/null action cancels an earlier reporting arm.
    cancel_fail(0);
    cancel_fail(1);
    cancel_pass(1);
    cancel_pass(0);

    #1;
    latest(0);
    latest(1);

    #1;
    // Replacing FIRST retains its first-pin position ahead of SECOND.
    first_source(1);
    second_source();
    first_source(0);

    #1 $display("PASSED");
  end
endmodule
