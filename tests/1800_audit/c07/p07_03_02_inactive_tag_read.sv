module test;
  typedef union tagged {
    int integer_value;
    logic [7:0] byte_value;
  } value_t;

  task automatic read_integer(input value_t value, output int result);
    result = value.integer_value;
  endtask

  initial begin
    value_t value;
    int result;
    value = tagged byte_value 8'h5A;
    $display("BEFORE_INACTIVE_TAG_READ");
    read_integer(value, result);
    $display("AFTER_INACTIVE_TAG_READ result=%0d", result);
    $finish;
  end
endmodule
