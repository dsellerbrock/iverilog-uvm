// Issue #2916: a guarded dist under a solve-before prefix whose projection
// is past the enumeration cap, and is not one full power-of-two variable,
// must not fail randomize() (IEEE 1800-2023 18.5.9, 18.5.3). The prefix is
// drawn uniformly over its projection; the dists act on the pinned fiber.
class leaf_a;
  rand bit [10:0] gate;
  rand bit x, y;
  constraint c { gate < 1500; solve gate before x, y;
                 if (gate[0]) { x dist {0 := 1, 1 := 3}; y dist {0 := 3, 1 := 1}; } }
endclass
class root_a;
  rand leaf_a child;
  function new(); child = new; endfunction
endclass

class leaf_b;
  rand bit [10:0] gate;
  rand bit [3:0] w;
  rand bit x, y;
  constraint c { solve gate, w before x, y;
                 if (gate[0] && w > 3) { x dist {0 := 1, 1 := 3}; y dist {0 := 3, 1 := 1}; } }
endclass
class root_b;
  rand leaf_b child;
  function new(); child = new; endfunction
endclass

module top;
  root_a ra = new;
  root_b rb = new;
  bit seen[1500];
  int fails = 0, distinct = 0, guarded = 0, x1 = 0, y1 = 0, guarded_b = 0, xb = 0;

  initial begin
    ra.srandom(32'h2916);
    rb.srandom(32'h6192);
    for (int i = 0; i < 400; i++) begin
      if (!ra.randomize()) fails++;
      if (ra.child.gate >= 1500) fails++;
      else if (!seen[ra.child.gate]) begin seen[ra.child.gate] = 1; distinct++; end
      if (ra.child.gate[0]) begin
        guarded++;
        x1 += ra.child.x;
        y1 += ra.child.y;
      end
      if (!rb.randomize()) fails++;
      if (rb.child.gate[0] && rb.child.w > 3) begin
        guarded_b++;
        xb += rb.child.x;
      end
    end
    // x is 1 with weight 3/4 and y with 1/4 where the guard holds.
    if (fails != 0 || distinct < 300 || guarded < 100
        || x1 * 100 < guarded * 60 || x1 * 100 > guarded * 90
        || y1 * 100 < guarded * 10 || y1 * 100 > guarded * 40
        || guarded_b < 50 || xb * 100 < guarded_b * 60)
      $display("FAILED: fails=%0d distinct=%0d guarded=%0d x1=%0d y1=%0d guarded_b=%0d xb=%0d",
               fails, distinct, guarded, x1, y1, guarded_b, xb);
    else
      $display("PASSED");
  end
endmodule
