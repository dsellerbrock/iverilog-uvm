// NEG-DIAG: argument 'values' has a type not supported for export
// NEG-DIAG-COUNT: 1
// IEEE 1800-2017/2023 35.5.6.1 and H.8.2 permit open-array formals only on
// imported DPI subroutines. An export must reject this form loudly.
module m10_dpi_export_open_array_argument;
  function int first_value(input int values[]);
    return values.size() ? values[0] : 0;
  endfunction
  export "DPI-C" function first_value;
endmodule
