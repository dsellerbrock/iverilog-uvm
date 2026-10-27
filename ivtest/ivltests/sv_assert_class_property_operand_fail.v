class sv_assert_class_property_operand_fail_class;
  int value;
endclass

module sv_assert_class_property_operand_fail;
  logic clk = 0;
  sv_assert_class_property_operand_fail_class object_handle = new;

  always #5 clk = ~clk;
  assert property (@(posedge clk) object_handle.value == 0);

  initial #12 $finish;
endmodule
