module test;
  task final_pass;
    $display("FINAL_ASSERT_PASS");
  endtask

  task final_fail;
    $display("FINAL_ASSERT_FAIL");
  endtask

  initial begin
    assert final (1'b1) final_pass();
    assert final (1'b0) else final_fail();
    cover final (1'b1) $display("FINAL_COVER_PASS");
    $display("ACTIVE_REGION_DONE");
    #1 $display("PASSED");
  end
endmodule
