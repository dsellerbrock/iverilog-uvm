// Both conditional arms are assignment-like contexts, including a dead arm.
module sv_assoc_default_const_ternary_fail;
  typedef int int_by_string_t[string];
  typedef string string_by_string_t[string];
  int_by_string_t value;

  initial
    value = 1'b1 ? int_by_string_t'{default:1}
                 : string_by_string_t'{default:"bad dead arm"};
endmodule
