module main;
  localparam logic signed [7:0] constant_value = 8'b000x0001;
  logic signed [7:0] value = 8'b000x0001;
  logic signed [7:0] unary_plus_result;
  logic signed [7:0] bitwise_not_result;
  logic signed [7:0] left_shift_result;
  logic signed [7:0] constant_or_result;

  initial begin
    unary_plus_result = +value;
    bitwise_not_result = ~value;
    left_shift_result = value << 1;
    constant_or_result = constant_value | 8'shff;
    if (unary_plus_result !== 8'hxx)
      $fatal(1, "signed unary plus did not produce all X: %b", unary_plus_result);
    if (bitwise_not_result !== 8'hxx)
      $fatal(1, "signed bitwise NOT did not produce all X: %b", bitwise_not_result);
    if (left_shift_result !== 8'hxx)
      $fatal(1, "signed left shift did not produce all X: %b", left_shift_result);
    if (constant_or_result !== 8'hxx)
      $fatal(1, "constant signed bitwise OR did not produce all X: %b", constant_or_result);
    value = 8'bz0000001;
    unary_plus_result = +value;
    bitwise_not_result = ~value;
    left_shift_result = value << 1;
    if (unary_plus_result !== 8'hxx)
      $fatal(1, "signed unary plus did not produce all X for Z: %b", unary_plus_result);
    if (bitwise_not_result !== 8'hxx)
      $fatal(1, "signed bitwise NOT did not produce all X for Z: %b", bitwise_not_result);
    if (left_shift_result !== 8'hxx)
      $fatal(1, "signed left shift did not produce all X for Z: %b", left_shift_result);
    $display("PASSED");
    $finish;
  end
endmodule
