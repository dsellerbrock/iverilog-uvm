// IEEE 1800-2017 7.4.6 and 8.3: a runtime-selected bit of an ascending
// packed vector class property uses the property's declared index range.

module class_property_ascending_variable_write_test;
  class register_t;
    logic [8:15] value;
  endclass

  initial begin
    automatic register_t reg_obj = new;
    automatic int index = 10;

    reg_obj.value = '0;
    reg_obj.value[index] = 1'b1;
    if (reg_obj.value !== 8'h20) begin
      $display("FAIL: ascending class-property bit write produced %h",
               reg_obj.value);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
