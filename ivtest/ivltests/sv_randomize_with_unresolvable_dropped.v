// A top-level item in a `randomize() with {...}` block that this
// compiler pass cannot translate to solver IR (here: a foreach
// constraint over a plain, non-rand class property that lives outside
// the randomized object's own class -- IEEE 1800-2017 allows a `with'
// block to reference enclosing-scope state, but this compiler does not
// yet resolve such foreach targets) used to be dropped completely
// silently: make_randomize_with_expr()'s constraint-collection loop
// did `if (ir.empty()) continue;` with no diagnostic at all, so
// randomize() still reported success while quietly ignoring part of
// the requested constraint set -- a real behavioral gap with zero
// visibility.
//
// This does not fix translation of such constraints (a separate,
// larger gap); it only verifies the drop is now loud (a
// compile-progress warning on stderr) rather than silent, and that
// the randomize() call still completes normally rather than hanging
// or crashing when one of its constraint items is unresolvable.
class item;
  rand int addr;
endclass

class driver;
  int lookup[3] = '{5, 10, 15};

  task run();
    item req = new;
    // The `addr inside {...}' item resolves normally; the foreach
    // item over `lookup' (a plain array outside item's own class)
    // does not and is dropped with a warning.
    void'(req.randomize() with {
        addr inside {[0:100]};
        foreach (lookup[i]) {
          addr != lookup[i];
        }
    });
    if (req.addr < 0 || req.addr > 100) begin
      $display("FAILED addr=%0d out of the resolvable range", req.addr);
      $finish;
    end
    $display("PASSED");
  endtask
endclass

module main;
  initial begin
    driver d = new;
    d.run();
  end
endmodule
