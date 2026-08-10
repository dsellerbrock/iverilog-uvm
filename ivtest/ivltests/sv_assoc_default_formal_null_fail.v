// The literal-null shortcut for class formals must not accept an AA formal.
module sv_assoc_default_formal_null_fail;
  typedef int int_by_string_t[string];

  function automatic bit accepts(input int_by_string_t value = null);
    return value.size() == 0;
  endfunction
endmodule
