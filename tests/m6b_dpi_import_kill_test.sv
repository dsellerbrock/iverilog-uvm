// M6B-3: a time-consuming DPI import participates in NORMAL scheduling,
// not just in "time advances while the C stack is parked".
//
// The two properties this pins, which the roadmap's probe m6b3_kill
// established and nothing kept honest:
//
//  1. A blocked import is an ordinary schedulable process: `fork` /
//     `join_any` returns as soon as a sibling completes, while the
//     import is still parked mid-body.
//  2. `disable fork` ABANDONS it. The exported SV task it is blocked in
//     never completes, its post-block work never runs, and the C body
//     never returns -- so neither the exported task's tail nor anything
//     after the import call in C is allowed to be observed.
//
// The discriminators are counters the C body and the exported task bump
// on either side of the block: `resumed' must stay 0 (the exported task
// never got past its delay) and `returns' must stay 0 (c_block never
// returned). A runtime that simply let the parked coroutine finish would
// show 1 and 1; one that leaked the killed thread back into the
// scheduler would show them late, after join_any already returned.
module m6b_dpi_import_kill_test;
  import "DPI-C" context task c_block();
  import "DPI-C" function int c_returns();

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
      else if (c_returns() != 0)
        $display("FAIL: the abandoned C import body returned (returns=%0d) after disable fork",
                 c_returns());
      else
        $display("PASS: disable fork abandoned the blocked DPI import at t=10; it never resumed");
    end
    $finish;
  end
endmodule
