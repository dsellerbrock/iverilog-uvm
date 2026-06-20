// Regression: constraint override by name across inheritance (IEEE 1800-2017
// §18.5.2).  A constraint declared in a derived class with the SAME NAME as a
// base-class constraint REPLACES the base one.
//
// iverilog previously asserted BOTH the derived and the overridden base
// constraint in the joint Z3 solve.  When they conflicted (e.g. x==50 in the
// derived vs x==7 in the base) the solve became UNSAT and randomize() bailed to
// free-random for ALL variables (returning success), so every rand member got
// garbage.  This is the OpenTitan uart_fifo_full_vseq case
// (weight_to_skip_rx_read_c ==7 base / ==50 derived), which left an unrelated
// rand enum (baud_rate) garbage and fataled get_nco.
//
// The fix skips ancestor constraints whose name is overridden by a more-derived
// class.  Note the blast radius: the contradiction corrupted ALL rand vars, so
// this test also checks an unrelated variable (y) stays in range.

module top;

  class base;
    rand int x;
    rand int y;
    constraint c  { x == 7; }
    constraint cy { y inside {[1:10]}; }
  endclass

  class deriv extends base;
    constraint c { x == 50; }   // overrides base::c by name -> x must be 50
  endclass

  initial begin
    deriv d = new();
    int errors = 0;
    for (int i = 0; i < 20; i++) begin
      if (!d.randomize()) begin
        $display("FAIL: randomize returned 0"); errors++;
      end else if (d.x != 50) begin
        $display("FAIL: overridden constraint not honored, x=%0d (expected 50)", d.x);
        errors++;
      end else if (d.y < 1 || d.y > 10) begin
        $display("FAIL: unrelated var corrupted, y=%0d (expected 1..10)", d.y);
        errors++;
      end
    end
    if (errors == 0) $display("PASS");
    else $display("constraint_override_by_name_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
