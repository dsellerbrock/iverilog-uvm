// Non-void function output validation must inspect associative-array metadata
// inside positional-container elements. A typed index mismatch and a
// typed-versus-wildcard mismatch are both non-equivalent element types.
typedef int function_assoc_string_inner_t[string];
typedef int function_assoc_int_inner_t[int];
typedef int function_assoc_wild_inner_t[*];
typedef function_assoc_int_inner_t function_assoc_int_queue_t[$];
typedef function_assoc_wild_inner_t function_assoc_wild_darray_t[];

module sv_nonvoid_function_assoc_element_formal_fail;
  int result;
  function_assoc_int_queue_t int_actual;
  function_assoc_wild_darray_t wildcard_actual;

  function automatic int output_string_darray(
        output function_assoc_string_inner_t value[]);
    value = new[1];
    value[0]["key"] = 41;
    return value.size();
  endfunction

  function automatic int output_int_queue(
        output function_assoc_int_inner_t value[$]);
    function_assoc_int_inner_t item;
    item[7] = 43;
    value.push_back(item);
    return value.size();
  endfunction

  initial begin
    result = output_string_darray(int_actual);
    result = output_int_queue(wildcard_actual);
  end
endmodule
