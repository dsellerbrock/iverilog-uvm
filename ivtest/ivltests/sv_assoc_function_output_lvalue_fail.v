// IEEE 1800-2017 13.5.2 requires an output actual to be an l-value.
module sv_assoc_function_output_lvalue_fail;
  typedef int assoc_t[string];
  int ignored;

  function automatic int fill(output assoc_t value);
    value = '{default:1};
    fill = value.size();
  endfunction

  initial ignored = fill('{default:9});
endmodule
