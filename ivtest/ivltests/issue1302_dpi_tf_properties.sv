module top;
  import "DPI-C" pure function int p(input int x);
  import "DPI-C" context c = function int c_sv(input int x);
  import "DPI-C" context c_task = task imported_task(input int x);
  import "DPI" function int legacy_dpi(input int x);
  function int e(input int x); return x; endfunction
  export "DPI-C" e_c = function e;
  task exported_task(input int x); endtask
  export "DPI-C" e_task_c = task exported_task;

  initial begin
    $probe_dpi_tf_properties;
    $finish;
  end
endmodule
