// M6B-3: a time-consuming DPI import participates in NORMAL scheduling,
// not just in "time advances while the C stack is parked".
//
// The two properties this pins, which the roadmap's probe m6b3_kill
// established and nothing kept honest:
//
//  1. A blocked import is an ordinary schedulable process: `fork` /
//     `join_any` returns as soon as a sibling completes, while the
//     import is still parked mid-body.
//  2. `disable fork` kills the SV execution but performs the IEEE 1800 35.9
//     foreign-language unwind. The exported task tail and SV import tail do
//     not run; C resumes exactly once to observe status/state 1, clean up,
//     and return acknowledgement 1.
//
// The discriminators are counters the C body and the exported task bump
// on either side of the block: `resumed' must stay 0 while C cleanup must be
// exactly 1. A runtime that lets the killed SV continuation finish shows a
// nonzero `resumed'; one that abandons the coroutine leaves cleanup at 0.
module m6b_dpi_import_kill_test;
  import "DPI-C" context task c_block();
  import "DPI-C" function int c_returns();
  import "DPI-C" function int c_export_status();
  import "DPI-C" function int c_disabled_state();

  int entered  = 0;   // exported task entered
  int resumed  = 0;   // exported task got past its blocking delay
  int sib_done = 0;

  task sv_block();
    entered++;
    #100;             // outlives the sibling, so join_any never waits for it
    resumed++;
  endtask
  export "DPI-C" task sv_block;

  initial begin
    fork
      c_block();               // parks inside sv_block's #100
      begin #10; sib_done++; end
    join_any
    disable fork;              // abandon the parked import

    if ($time != 10)
      $display("FAIL: join_any returned at t=%0t (want 10); a blocked DPI import is not scheduling normally",
               $time);
    else if (entered != 1)
      $display("FAIL: the exported task was entered %0d times (want 1); the test itself is broken",
               entered);
    else if (sib_done != 1)
      $display("FAIL: the sibling did not complete (sib_done=%0d)", sib_done);
    else begin
      // Give the abandoned process every chance to wrongly wake up.
      #200;
      if (resumed != 0)
        $display("FAIL: the abandoned exported task resumed (resumed=%0d) after disable fork",
                 resumed);
      else if (c_returns() != 1)
        $display("FAIL: disabled C cleanup count is %0d (want 1)",
                 c_returns());
      else if (c_export_status() != 1)
        $display("FAIL: exported-task disable status is %0d (want 1)",
                 c_export_status());
      else if (c_disabled_state() != 1)
        $display("FAIL: svIsDisabledState result is %0d (want 1)",
                 c_disabled_state());
      else
        $display("PASS: disable fork unwound the blocked DPI import with status/ack 1 at t=10");
    end
    $finish;
  end
endmodule
