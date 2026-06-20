// Regression: `inside` with an EXPRESSION (not a literal) as a range bound.
//
// The Z3 IR `inside`-range parser read a single token and strtoull'd it as a
// `c:N` literal.  When a bound was an expression -- e.g.
// `x inside {[(a+b+1):100]}` -> IR `(inside p:N:W [(add (add c:.. c:..) c:..),c:100])`
// -- it misparsed, corrupting the parse into a degenerate Z3 expression that
// made Z3_optimize_check HANG (sim froze at one timestamp).  This is the
// OpenTitan reg-model `randomize() with` at ~1.56us that hung the heavier UART
// DV tests.  Fix: parse bounds via build_z3_atom (handles expressions) + width
// coercion to the subject.
module top;
  class C;
    rand bit [63:0] x;   // wide property: exercised the bit-blast hang
    rand int        y;
  endclass
  initial begin
    C c = new();
    int a = 10, b = 2;
    int errors = 0;
    for (int i = 0; i < 20; i++) begin
      if (!c.randomize() with { x inside {[(a + b + 1) : 100]}; y inside {[5:9]}; }) begin
        $display("FAIL: randomize returned 0"); errors++;
      end else if (c.x < (a+b+1) || c.x > 100) begin
        $display("FAIL: x=%0d out of [%0d,100]", c.x, a+b+1); errors++;
      end else if (c.y < 5 || c.y > 9) begin
        $display("FAIL: y=%0d out of [5,9]", c.y); errors++;
      end
    end
    if (errors == 0) $display("PASS");
    else $display("inside_expr_range_bound_test FAILED with %0d errors", errors);
    $finish;
  end
endmodule
