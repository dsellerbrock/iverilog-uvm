// NEG-DIAG: DPI function result type is not permitted by IEEE 1800 Annex H.8.9
// NEG-DIAG-COUNT: 2
// H.7.3 maps an enum through its base type. A packed-vector base therefore
// remains illegal as a DPI function result for both import and export.
module m10_dpi_packed_enum_function_return;
  typedef enum logic [7:0] {
    ENUM_ZERO = 8'h00,
    ENUM_ONE = 8'h01
  } packed_enum_t;

  import "DPI-C" function packed_enum_t c_bad_packed_enum_return();

  function packed_enum_t sv_bad_packed_enum_return();
    return ENUM_ONE;
  endfunction
  export "DPI-C" function sv_bad_packed_enum_return;
endmodule
