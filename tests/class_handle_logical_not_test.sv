// IEEE 1800-2017 11.4.7: logical negation of a class handle is a one-bit
// integral value. The core expression node previously retained the class
// operand type, so code generation replaced !handle with a null object.
class class_handle_logical_not_item;
endclass

module class_handle_logical_not_test;
  class_handle_logical_not_item item;

  initial begin
    item = null;
    if (!item) begin end
    else $fatal(1, "!null was not true");
    item = new();
    if (!item) $fatal(1, "!live_handle was not false");
    if (item) begin end
    else $fatal(1, "live handle was not true");
    $display("CLASS HANDLE LOGICAL NOT TEST: PASS");
    $finish(0);
  end
endmodule
