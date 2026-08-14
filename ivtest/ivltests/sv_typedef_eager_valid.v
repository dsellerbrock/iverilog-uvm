typedef resolved_forward_t;
typedef logic [2:0] resolved_forward_t;

module typedef_parameter_scope #(
  parameter integer WIDTH = 5
) (
  output logic passed
);
  typedef logic [WIDTH-1:0] parameter_word_t;
  parameter_word_t value;

  initial begin
    value = '1;
    passed = $bits(value) == WIDTH && value == {WIDTH{1'b1}};
  end
endmodule

class typedef_parameter_class #(
  parameter integer WIDTH = 7
);
  typedef logic [WIDTH-1:0] parameter_word_t;
  parameter_word_t value;
endclass

module sv_typedef_eager_valid;
  logic module_ok;
  resolved_forward_t forward_value;
  typedef_parameter_class #(9) object;
  typedef_parameter_scope #(6) parameter_test(module_ok);

  initial begin
    object = new;
    object.value = '1;
    forward_value = '1;
    #1;
    if (module_ok && $bits(forward_value) == 3
        && $bits(object.value) == 9 && object.value == 9'h1ff)
      $display("PASSED");
    else
      $display("FAILED module=%b forward_bits=%0d class_bits=%0d class=%h",
               module_ok, $bits(forward_value), $bits(object.value), object.value);
  end
endmodule
