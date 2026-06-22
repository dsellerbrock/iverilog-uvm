// Regression: a constraint `foreach` over a MEMBER/hierarchical array target,
// e.g. `foreach (cfg.regs.csnlead[i]) { ... }` (OpenTitan spi_host vseqs).
//
// The constraint-context foreach rule only accepted a simple IDENTIFIER array
// name, so a member-path target failed to parse and desynced the parser — the
// surrounding class items were reported as "Invalid class item" (cascading to
// dozens of spurious errors). Targeted 2-/3-component dotted forms now parse
// it; the constraint keys off the leaf array name (and harmlessly drops to a
// no-op in the IR when the leaf isn't a direct property of the constraining
// class), so the class compiles. Zero new grammar conflicts.
module top;
  class regs_t;
    rand bit [3:0] csnlead[4];
    rand bit [3:0] csntrail[4];
  endclass

  class c;
    regs_t cfg_regs;
    function new(); cfg_regs = new(); endfunction
    // member-array foreach targets in a constraint
    constraint cfg_c {
      foreach (cfg_regs.csnlead[i])  { cfg_regs.csnlead[i]  == 0; }
      foreach (cfg_regs.csntrail[i]) { cfg_regs.csntrail[i] inside {[0:3]}; }
    }
    // a class item AFTER the constraint must still parse (no cascade)
    function int sentinel(); return 42; endfunction
  endclass

  initial begin
    c o = new();
    void'(o.randomize());
    if (o.sentinel() == 42) $display("PASS");
    else $display("FAIL");
  end
endmodule
