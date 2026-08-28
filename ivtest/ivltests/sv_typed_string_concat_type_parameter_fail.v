// IEEE 1800-2017/2023 Table 6-9: a generic class body must defer concat
// operand legality until its type parameter is specialized. Once T is
// concretely int, mixing that operand with a string expression is illegal.
class sv_typed_string_concat_type_parameter_bad #(type T = int);
  static function string describe(T value);
    string prefix = "prefix";
    return {prefix, value};
  endfunction
endclass

module sv_typed_string_concat_type_parameter_fail;
  initial $display("%s",
    sv_typed_string_concat_type_parameter_bad#(int)::describe(65));
endmodule
