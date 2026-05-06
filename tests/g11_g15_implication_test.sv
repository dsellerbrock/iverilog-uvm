// G11/G15 (Phase 66): implication constraint A -> B
// Tests `(cond) -> (consequence)` in class constraint blocks.
class Foo;
  rand int x;
  rand int y;
  constraint c {
    x inside {[0:1]};
    (x == 0) -> (y == 99);
    (x == 1) -> (y inside {[200:300]});
  }
endclass

module top;
  Foo f;
  int ok, fail;
  initial begin
    f = new;
    ok = 0; fail = 0;
    repeat (20) begin
      void'(f.randomize());
      if (f.x == 0 && f.y != 99) fail++;
      else if (f.x == 1 && (f.y < 200 || f.y > 300)) fail++;
      else ok++;
    end
    if (fail == 0)
      $display("PASS: implication constraints hold (%0d iterations)", ok);
    else
      $display("FAIL: %0d implication violations (last x=%0d y=%0d)", fail, f.x, f.y);
    $finish;
  end
endmodule
