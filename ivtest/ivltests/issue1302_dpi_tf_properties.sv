module top;
  import "DPI-C" pure function int dpi_pure(input int x);
  import "DPI-C" context dpi_context_c = function int dpi_context(output int x);
  import "DPI-C" context dpi_task_c = task dpi_task(input int x);
  export "DPI-C" dpi_export_c = function dpi_export;
  export "DPI-C" dpi_export_task_c = task dpi_export_task;
  function int dpi_export(input int x);
    return x;
  endfunction
  task dpi_export_task(input int x);
  endtask
endmodule
