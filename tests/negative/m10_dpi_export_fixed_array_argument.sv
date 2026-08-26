// NEG-DIAG: fixed unpacked array argument 'values' is not yet supported for DPI export
// NEG-DIAG-COUNT: 1
// A fixed unpacked atom array uses a direct C pointer ABI. Until export-side
// pointer marshaling is implemented, it must never fall through to the scalar
// element-width classifier and generate a falsely compatible C prototype.
module m10_dpi_export_fixed_array_argument;
  function int first_value(input int values[2]);
    return values[0];
  endfunction
  export "DPI-C" function first_value;
endmodule
