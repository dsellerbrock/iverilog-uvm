// Locator result element types remain visible through a function argument.
module sv_array_locator_wrapper_type_fail;
  int values[2] = '{1, 2};
  function automatic int consume_strings(input string items[$]);
    return items.size();
  endfunction
  initial $display("%0d", consume_strings(values.find(item) with (item > 0)));
endmodule
