module top;
  logic signed [7:0] value_x = 8'b000x0001;
  logic signed [7:0] value_z = 8'b000z0001;
  logic signed [7:0] result;

  initial begin
    result = +value_x;
    if (result !== 8'hxx)
      $fatal(1, "unary plus with signed X produced %b", result);
    result = ~value_x;
    if (result !== 8'hxx)
      $fatal(1, "bitwise NOT with signed X produced %b", result);
    result = value_x << 1;
    if (result !== 8'hxx)
      $fatal(1, "left shift with signed X produced %b", result);
    result = value_z << 1;
    if (result !== 8'hxx)
      $fatal(1, "left shift with signed Z produced %b", result);
    $display("PASSED");
  end
endmodule
