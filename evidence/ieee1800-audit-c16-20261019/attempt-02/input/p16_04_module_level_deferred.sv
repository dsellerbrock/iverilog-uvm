module test;
  task report_module_failure;
    $display("MODULE_ITEM_FAIL");
  endtask

  module_check: assert #0 (1'b0) else report_module_failure();

  initial begin
    #1 $display("PASSED");
  end
endmodule
