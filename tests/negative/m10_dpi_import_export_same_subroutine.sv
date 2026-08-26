// NEG-DIAG: cannot also be exported
// NEG-DIAG-COUNT: 1
// A deferred export-resolution error must both diagnose and make compilation
// fail; historically pform_finish reset its error count before main used it.
module m10_dpi_import_export_same_subroutine;
  import "DPI-C" function int imported_function();
  export "DPI-C" function imported_function;
endmodule
