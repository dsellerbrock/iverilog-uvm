// Wildcard and explicitly typed associative indices are distinct types.
module sv_assoc_wildcard_type_fail;
  typedef int typed_t[string];
  typedef int wildcard_t[*];
  typed_t target;
  wildcard_t source;
  bit sink;

  function automatic bit accepts(input typed_t value);
    return value.size() == 0;
  endfunction

  initial begin
    target = source;
    target = typed_t'(source);
    sink = accepts(source);
  end
endmodule
