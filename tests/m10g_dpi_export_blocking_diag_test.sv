// M10-2 malformed-boundary robustness: IEEE 1800 35.8 forbids an exported
// task from being reached through an imported DPI *function* at all. This is
// intentionally not a VCS/Questa/Xcelium portability test. For an old image
// or malformed foreign caller that nevertheless does it, a time-consuming
// export has no coroutine to park on and must produce a LOUD diagnostic,
// never a crash.
//
// It used to abort vvp: the inline runner spun the child past its
// delay and then joined it while the scheduler still held a future
// event for it, tripping assert(is_scheduled) in vthread_run (and,
// once that was stopped, assert(children.empty()) in of_END).
//
// Now the runner stops as soon as the child delays, reports the
// unsupported case, and detaches the child so it completes on its own
// under the scheduler. The zero-time exports around it keep working,
// and the C caller resumes normally.
//
// (The SUPPORTED time-consuming path -- an exported task reached from
// an imported DPI *task*, which runs on a coroutine -- is covered by
// m10f_dpi_export_timeconsuming_test.)
module top;
  export "DPI-C" function sv_zero;      // zero-time: must work
  export "DPI-C" task sv_blocks;        // time-consuming: must diagnose

  int zero_calls = 0;
  int resumed_at = -1;

  function int sv_zero(int a);
    zero_calls++;
    return a + 1;
  endfunction

  task sv_blocks();
    #5 resumed_at = $time;
  endtask

  import "DPI-C" context function void c_drive();

  initial begin
    c_drive();
    // The C call returned even though the export could not block.
    #20;
    if (zero_calls == 2 && resumed_at == 5)
      $display("PASS m10g_dpi_export_blocking_diag_test");
    else
      $display("FAIL zero_calls=%0d resumed_at=%0d", zero_calls, resumed_at);
    $finish;
  end
endmodule
