// NEG-DIAG: already used by another export in this scope
// NEG-DIAG-COUNT: 1
// Two locally visible exports cannot claim one C identifier even when their
// C signatures happen to match; svSetScope cannot distinguish them.
module m10_dpi_export_same_scope_c_name;
  function int first_function(int value);
    return value;
  endfunction

  function int second_function(int value);
    return value + 1;
  endfunction

  export "DPI-C" shared_local_name = function first_function;
  export "DPI-C" shared_local_name = function second_function;
endmodule
