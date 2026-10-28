interface issue1260_bus_if;
  task run;
  endtask
  function int get;
    get = 1;
  endfunction
  modport mp(import run, get);
endinterface

module issue1260_vpi_access;
  issue1260_bus_if bus();
  import "DPI-C" function int dpi_import();
  export "DPI-C" function dpi_export;
  function int dpi_export;
    dpi_export = 0;
  endfunction

  initial $check_issue1260_access;
endmodule
