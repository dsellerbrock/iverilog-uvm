// G20 (Phase 66): child class constraint referencing parent rand property
// Tests that `y == x * 2` (child constraint) is solved jointly with
// `x inside {[1:50]}` (parent constraint).
class P;
  rand int x;
  constraint cP { x inside {[1:50]}; }
endclass

class C extends P;
  rand int y;
  constraint cC { y == x * 2; }
endclass

module top;
  C c;
  int fail;
  initial begin
    c = new; fail = 0;
    repeat (20) begin
      void'(c.randomize());
      if (c.x < 1 || c.x > 50) begin fail++; end
      if (c.y != c.x * 2)      begin fail++; end
    end
    if (fail == 0)
      $display("PASS: cross-class constraint solved jointly (x=%0d y=%0d)", c.x, c.y);
    else
      $display("FAIL: %0d violations (x=%0d y=%0d)", fail, c.x, c.y);
    $finish;
  end
endmodule
