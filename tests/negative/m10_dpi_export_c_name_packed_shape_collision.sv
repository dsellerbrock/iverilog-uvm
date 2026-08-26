// NEG-DIAG: incompatible declarations
// NEG-DIAG-COUNT: 1
// The canonical C pointer spelling alone is insufficient to match packed
// DPI formals: dimensions, bounds, width, and signedness are part of the
// type signature selected by svSetScope.
module dpi_export_narrow_scope;
  function void packed_narrow(input bit [7:0] value);
  endfunction
  export "DPI-C" shared_packed_name = function packed_narrow;
endmodule

module dpi_export_wide_scope;
  function void packed_wide(input bit [0:15] value);
  endfunction
  export "DPI-C" shared_packed_name = function packed_wide;
endmodule

module m10_dpi_export_c_name_packed_shape_collision;
  dpi_export_narrow_scope narrow_scope();
  dpi_export_wide_scope wide_scope();
endmodule
