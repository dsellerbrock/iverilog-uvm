// M3B-3: `disable soft <var>;` inside a constraint removes soft constraints
// on that variable for this randomize() call (IEEE 1800-2017 18.5.14.1).
// Self-checking by contrast: an identical class WITHOUT `disable soft` keeps
// the soft preference (x == 5), while WITH `disable soft` the preference is
// dropped and x ranges freely over the hard constraint.

class WithDisable;
  rand int x;
  constraint c_soft { soft x == 5; }
  constraint c_hard { disable soft x; x inside {[1:20]}; }
endclass

class NoDisable;
  rand int x;
  constraint c_soft { soft x == 5; }
  constraint c_hard { x inside {[1:20]}; }
endclass

module sv_disable_soft;
  int errors = 0;
  initial begin
    automatic WithDisable wd = new;
    automatic NoDisable   nd = new;
    int wd_fives = 0, wd_other = 0, wd_oob = 0;
    int nd_fives = 0;

    for (int i = 0; i < 30; i++) begin
      void'(wd.randomize());
      if (wd.x < 1 || wd.x > 20) wd_oob++;    // hard constraint must hold
      if (wd.x == 5) wd_fives++; else wd_other++;
      void'(nd.randomize());
      if (nd.x == 5) nd_fives++;
    end

    // Hard constraint always holds.
    if (wd_oob != 0) begin $display("FAILED hard-range violated %0d times", wd_oob); errors++; end
    // WITHOUT disable soft: the soft preference x==5 is honored every time.
    if (nd_fives != 30) begin $display("FAILED soft not honored (nd_fives=%0d exp 30)", nd_fives); errors++; end
    // WITH disable soft: the soft preference is dropped, so x is not pinned to 5.
    if (wd_other == 0) begin $display("FAILED disable-soft did not drop soft (all x==5)"); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
