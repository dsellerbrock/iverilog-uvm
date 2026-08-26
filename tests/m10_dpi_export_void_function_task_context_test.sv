// A zero-time exported void function reached from an imported DPI task runs
// on the same coroutine bridge as a time-consuming exported task. Its
// output/inout values must be copied to C before the scheduler reaps the
// automatic function activation. The shortreal, svLogic, and string formals
// also pin the commercial Annex-H scalar-formal C signatures on this call
// path. The imported task's C definition also returns the normal H.8.2
// acknowledgement value zero; the exported void function retains its void C
// ABI because it is a function, not a task.
module m10_dpi_export_void_function_task_context_test;
  import "DPI-C" context task c_check_void_export(output int failures);

  function automatic void sv_void_copyout(
      input int addend, output shortreal out_shortreal,
      inout int inout_value, output logic out_logic,
      output string out_string, inout string inout_string);
    out_shortreal = 2.5;
    inout_value += addend;
    out_logic = 1'bz;
    out_string = "out:sv";
    inout_string = {inout_string, ":sv"};
  endfunction
  export "DPI-C" function sv_void_copyout;

  int failures;
  initial begin
    c_check_void_export(failures);
    if (failures == 0)
      $display("PASS m10_dpi_export_void_function_task_context_test");
    else
      $display("FAIL m10_dpi_export_void_function_task_context_test failures=%0d",
               failures);
    $finish;
  end
endmodule
