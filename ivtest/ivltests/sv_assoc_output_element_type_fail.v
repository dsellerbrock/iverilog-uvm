// A pure output task actual is checked when the formal is copied back.
module sv_assoc_output_element_type_fail;
  typedef int int_by_string_t[string];
  typedef string string_by_string_t[string];
  string_by_string_t actual;

  task automatic produce(output int_by_string_t value);
    value = '{default:1};
  endtask

  initial produce(actual);
endmodule
