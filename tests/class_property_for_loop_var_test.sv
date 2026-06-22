// A class property used directly as a for-loop control variable
//   for (member = 0; member < N; member++)
// failed with "register `member' unknown": PForStatement::elaborate looked
// the loop variable up only via des->find_signal(), which does not resolve
// class properties (they are not signals).  Plain assignments to the same
// member worked, so the failure was specific to the for-loop init clause.
//
// This is the OpenTitan usbdev_endpoint_access_vseq pattern: an inherited
// `rand bit [3:0] ep_default;` driven by `for (ep_default = 0; ...)`.
//
// The fix elaborates the init as a normal l-value assignment and lifts it in
// front of a NetForLoop with no built-in init, keeping cond/step inside the
// loop (so continue/break still work).
module class_property_for_loop_var_test;
  class base;
    rand bit [3:0] ep;          // inherited member used as loop var
  endclass
  class deriv extends base;
    bit [3:0] own;              // own member used as loop var
    function int run();
      int sum_ep = 0, sum_own = 0, cont_hits = 0;
      for (ep = 0; ep < 4; ep++) sum_ep += ep;            // 0+1+2+3 = 6
      for (own = 0; own < 3; own++) sum_own += own;       // 0+1+2   = 3
      // continue must jump to step (ep++), not skip it -> still terminates
      for (ep = 0; ep < 5; ep++) begin
        if (ep == 2) continue;
        cont_hits++;                                      // hits ep=0,1,3,4 = 4
      end
      if (sum_ep == 6 && sum_own == 3 && cont_hits == 4 && ep == 5)
        return 1;
      $display("sum_ep=%0d sum_own=%0d cont=%0d ep=%0d",
               sum_ep, sum_own, cont_hits, ep);
      return 0;
    endfunction
  endclass
  initial begin
    deriv d = new();
    if (d.run()) $display("PASS");
    else         $display("FAIL");
    $finish;
  end
endmodule
