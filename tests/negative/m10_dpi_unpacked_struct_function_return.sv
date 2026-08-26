// NEG-DIAG: DPI function result type is not permitted by IEEE 1800 Annex H.8.9
// NEG-DIAG-COUNT: 2
// H.8.9 permits only small-value DPI function results. An unpacked aggregate
// is illegal for both imported and exported functions and must be rejected
// before any target attempts to select a native return ABI.
module m10_dpi_unpacked_struct_function_return;
  typedef struct {
    int first;
    longint second;
  } result_t;

  import "DPI-C" function result_t c_bad_struct_return();

  function result_t sv_bad_struct_return();
  endfunction
  export "DPI-C" function sv_bad_struct_return;
endmodule
