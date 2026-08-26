// NEG-DIAG: already has a DPI export declaration
// NEG-DIAG-COUNT: 1
// One SystemVerilog subroutine has one DPI export declaration; two different
// C aliases must not make its generated/export metadata order-dependent.
module m10_dpi_export_same_subroutine_twice;
  function int exported_function(int value);
    return value;
  endfunction

  export "DPI-C" first_c_name = function exported_function;
  export "DPI-C" second_c_name = function exported_function;
endmodule
