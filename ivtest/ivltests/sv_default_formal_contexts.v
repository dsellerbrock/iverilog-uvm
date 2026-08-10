// Default arguments are assignment-like contexts for every formal category.
module sv_default_formal_contexts;
  class C; endclass

  function automatic int scalar_default(input byte value = 257);
    return value;
  endfunction

  function automatic int queue_default(input int value[$] = {});
    return value.size();
  endfunction

  function automatic int darray_default(input int value[] = {});
    return value.size();
  endfunction

  function automatic bit class_default(input C value = null);
    return value == null;
  endfunction

  initial begin
    if (scalar_default() != 1 || queue_default() != 0 ||
        darray_default() != 0 || !class_default())
      $fatal(1, "FAILED -- default formal context");
    $display("PASSED");
  end
endmodule
