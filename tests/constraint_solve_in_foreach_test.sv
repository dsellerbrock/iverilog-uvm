// Regression: a `solve a before b;` ordering directive INSIDE a foreach/if
// constraint body, e.g. OpenTitan sysrst_ctrl:
//   constraint c { foreach (dur[i]) { solve dur[i] before cyc; cyc dist {...}; } }
//
// `solve` was only a constraint_block_item (the top-level constraint body), not
// a constraint_expression (used by constraint_set inside foreach/if). So a
// `solve` nested in a foreach desynced the parser and the whole class became a
// cascade of "Invalid class item" errors (sysrst_ctrl: 1530 errors, ~all from
// this one desync). Adding `solve a before b;` to constraint_expression
// (single-expression form, +1 s/r conflict) fixes it. solve-before only affects
// solver variable ordering, which the IR path doesn't model, so it's parsed and
// discarded.
module top;
  class c;
    rand int unsigned dur[3];
    rand int unsigned cyc;
    int unsigned tk = 5;
    constraint cyc_c {
      foreach (dur[i]) {
        solve dur[i] before cyc;
        cyc dist { [1:(dur[i]+tk)] :/ 5, [(dur[i])+6:(dur[i]+tk)*2] :/ 95 };
      }
    }
    // class item AFTER the constraint must still parse (no cascade)
    function int sentinel(); return 9; endfunction
  endclass

  initial begin
    c o = new();
    void'(o.randomize());
    if (o.sentinel() == 9) $display("PASS");
    else $display("FAIL");
  end
endmodule
