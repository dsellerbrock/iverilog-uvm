// IEEE 1800-2017/2023 Table 6-9 applies to procedural assignments as well
// as parameters: an integral operand mixed with a string expression requires
// an explicit string cast.
class sv_typed_string_property_collision_obj;
  static string f = "STATIC";
endclass

module sv_typed_string_property_collision_leaf;
  int f = 65;
endmodule

module sv_typed_string_concat_procedural_mixed_fail;
  string value;
  int code;
  bit choose;
  sv_typed_string_property_collision_leaf
    sv_typed_string_property_collision_obj();
  initial begin
    value = "prefix";
    value = {value, code};
    value = choose ? {value, code} : "fallback";
    value = string'({value, code});
    value = {value, sv_typed_string_property_collision_obj.f};
  end
endmodule
