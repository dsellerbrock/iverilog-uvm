// OpenTitan compatibility accepts a selected byte only when its underlying
// object is string. A byte-sized select from an ordinary packed vector is
// still integral and requires an explicit string cast (IEEE 1800-2017/2023
// 6.16 and Table 6-9). An int-returning zero-argument static function
// remains integral when its call parentheses are omitted as well. A selected
// string character has byte type and therefore has no string methods.
class sv_typed_string_integral_source;
  static function int value();
    return 65;
  endfunction
endclass

typedef struct {
  string value;
} sv_typed_string_struct_holder;

class sv_typed_string_class_holder;
  string value;
endclass

module sv_typed_string_concat_vector_select_fail;
  localparam string PARAM_SOURCE = "parameter";
  string value;
  string source;
  logic [15:0] packed_value;
  int selected_length;
  sv_typed_string_struct_holder struct_holder;
  sv_typed_string_class_holder class_holder;
  initial begin
    value = "prefix";
    value = {value, packed_value[7:0]};
    value = {value, sv_typed_string_integral_source::value};
    selected_length = source[0].len();
    selected_length = PARAM_SOURCE[0].len();
    selected_length = struct_holder.value[0].len();
    class_holder = new;
    selected_length = class_holder.value[0].len();
  end
endmodule
