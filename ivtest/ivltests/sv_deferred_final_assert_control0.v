module t;
  task automatic controlled(input bit ok);
    assert final (ok) else $display("CONTROLLED_FAIL");
  endtask

  initial begin
    $assertoff;
    controlled(0);
    $asserton;
    controlled(0);
    // Disabling after a pin neither cancels it nor permits a disabled
    // execution to overwrite it.
    $assertoff;
    controlled(1);

    #1;
    $asserton;
    controlled(0);
    controlled(1);
    #1 $display("PASSED");
  end
endmodule
