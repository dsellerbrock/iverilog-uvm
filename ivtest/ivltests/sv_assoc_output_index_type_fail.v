// Associative key type is part of pure output task copy-back compatibility.
module sv_assoc_output_index_type_fail;
  typedef int int_by_string_t[string];
  typedef int int_by_int_t[int];
  int_by_int_t actual;

  task automatic produce(output int_by_string_t value);
    value = '{default:1};
  endtask

  initial produce(actual);
endmodule
