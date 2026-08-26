// NEG-DIAG: incompatible declarations
// NEG-DIAG-COUNT: 1
// IEEE 1800 DPI exports sharing a C identifier must denote one compatible
// C entry point. A task uses the Annex H int status ABI, while a void
// function returns void; silently choosing either declaration is invalid.
module dpi_export_function_scope;
  function void sv_function();
  endfunction
  export "DPI-C" shared_c_name = function sv_function;
endmodule

module dpi_export_task_scope;
  task sv_task();
  endtask
  export "DPI-C" shared_c_name = task sv_task;
endmodule

module m10_dpi_export_c_name_abi_collision;
  dpi_export_function_scope function_scope();
  dpi_export_task_scope task_scope();
endmodule
