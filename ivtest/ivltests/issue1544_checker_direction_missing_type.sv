checker input_missing_type(input a); endchecker
checker output_missing_type(output b); endchecker

// These forms remain valid: a direction-inferred untyped input and an
// explicitly directed typed input.
checker implicit_untyped(a); endchecker
checker explicit_typed(input logic c); endchecker

module issue1544_top;
endmodule
