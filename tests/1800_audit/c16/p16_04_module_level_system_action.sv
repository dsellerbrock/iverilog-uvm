module test;
  module_check: assert #0 (1'b0) else $display("MODULE_ITEM_FAIL");

  initial begin
    #1 $display("PASSED");
  end
endmodule
