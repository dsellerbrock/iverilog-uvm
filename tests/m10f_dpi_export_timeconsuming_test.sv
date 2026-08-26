// DPI export, time-consuming task (IEEE 1800-2017 35.5): an imported DPI
// *task* whose C body calls an exported SV *task* that blocks on #delay.
// The C call stack is suspended while simulation time advances and resumed
// when the SV task completes. Exercises: an argument to the exported task,
// two blocking exported calls within one import call, a concurrent process
// that must run DURING the delays (proving time genuinely advances, the C
// stack is parked rather than blocking the scheduler), and a self-check on
// the final time and accumulated value. The exported task's output/inout
// formals also prove that the resumed C stack receives copy-out values before
// the scheduler reaps the completed automatic activation.
//
// Supported on all platforms: the C stack is parked on a coroutine backend
// (POSIX <ucontext.h> on Linux/macOS, Win32 Fibers on MinGW/Windows).
module m10f_dpi_export_timeconsuming_test;
  import "DPI-C" context task c_run(int reps, output int copied_total,
                                      inout int seed);

  int acc;
  int concurrent_ticks;
  int copied_total;
  int seed;

  task automatic sv_delay_add(int amount, output int copied_total,
                              inout int seed);
    #5;  acc += amount;
    #5;  acc += amount;
    copied_total = acc;
    seed += amount;
  endtask
  export "DPI-C" task sv_delay_add;

  // Must interleave with the exported task's delays.
  initial begin
    #3  concurrent_ticks++;
    #4  concurrent_ticks++;
    #4  concurrent_ticks++;
  end

  initial begin
    seed = 7;
    c_run(2, copied_total, seed);
    // Two sv_delay_add(10) calls => 20 ns, acc/copy = 40, seed = 27.
    $display("  final t=%0t acc=%0d copied_total=%0d seed=%0d concurrent_ticks=%0d",
             $time, acc, copied_total, seed, concurrent_ticks);
    if ($time == 20 && acc == 40 && copied_total == 40 && seed == 27 &&
        concurrent_ticks == 3)
      $display("PASS m10f_dpi_export_timeconsuming_test");
    else
      $display("FAIL t=%0t acc=%0d copied_total=%0d seed=%0d ticks=%0d",
               $time, acc, copied_total, seed, concurrent_ticks);
    $finish;
  end
endmodule
