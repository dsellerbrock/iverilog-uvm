// DPI export (IEEE 1800-2017 35.5): a C task imported into SV calls
// back into exported SV subroutines and the results round-trip correctly.
// Exercises int/signed/byte/longint/real returns, a void function, a task,
// and the `export c_name = function sv_name' alias form. The exported C
// stubs are emitted by iverilog into <out>.dpiexport.c and compiled into
// the DPI object by the harness.
module m10c_dpi_export_test;
  import "DPI-C" context task run_all(output int failures);

  function int      f_add (int a, int b);      return a + b;         endfunction
  function int      f_sub (int a, int b);      return a - b;         endfunction // signed negative
  function byte     f_byte(byte x);            return x + 8'sd10;    endfunction
  function longint  f_long(longint x);         return x * 2;         endfunction
  function real     f_real(real x);            return x * 1.5;       endfunction
  function void     f_void(int x);             $display("  f_void got %0d", x); endfunction
  task              t_task(int x);             $display("  t_task got %0d", x); endtask

  // Export declarations follow their definitions (the supported form).
  export "DPI-C" function f_add;
  export "DPI-C" function f_sub;
  export "DPI-C" c_byte = function f_byte;   // alias: C name differs from SV name
  export "DPI-C" function f_long;
  export "DPI-C" function f_real;
  export "DPI-C" function f_void;
  export "DPI-C" task     t_task;

  int failures;
  initial begin
    // An exported task may only be reached through a context imported task,
    // never through an imported function (IEEE 1800 35.8).
    run_all(failures);
    if (failures == 0) $display("PASS m10c_dpi_export_test");
    else               $display("FAIL m10c_dpi_export_test");
    $finish;
  end
endmodule
