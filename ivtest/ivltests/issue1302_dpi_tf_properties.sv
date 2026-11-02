module top;
  import "DPI-C" pure function int p(input int x);
  import "DPI-C" context function int c(input int x);
  import "DPI-C" c_alias = function int alias_fn(input int x);
  import "DPI" pure c_legacy = function int legacy_fn(input int x);
  import "DPI-C" context task c_task(input int x);
  import "DPI-C" task_alias = task alias_task(input int x);
  import "DPI" context c_legacy_task = task legacy_task(input int x);

  export "DPI-C" function e;
  export "DPI" c_legacy_export = function legacy_export;
  export "DPI-C" task e_task;
  export "DPI-C" c_task_export = task task_export;
  export "DPI" c_legacy_task_export = task legacy_task_export;

  function int e(input int x); return x; endfunction
  function int legacy_export(input int x); return x; endfunction
  task e_task(input int x); endtask
  task task_export(input int x); endtask
  task legacy_task_export(input int x); endtask

  initial $finish;
endmodule
