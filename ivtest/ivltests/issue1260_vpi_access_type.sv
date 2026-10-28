interface issue1260_bus_if;
  task run; endtask
  function int get; return 1; endfunction
  modport mp(import run, get);
endinterface

module top;
  issue1260_bus_if bus();

  import "DPI-C" function int dpi_import_fn(input int value);
  import "DPI-C" task dpi_import_task(input int value);
  function int dpi_export_fn(input int value); return value; endfunction
  task dpi_export_task(input int value); endtask
  export "DPI-C" function dpi_export_fn;
  export "DPI-C" task dpi_export_task;

  initial begin
    $probe_access_type;
    $finish;
  end
endmodule
