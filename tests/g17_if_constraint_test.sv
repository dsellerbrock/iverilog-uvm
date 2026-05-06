// G17 (Phase 66): if-block constraint
// Tests `if(cond) { A; B; } else { C; }` in constraint blocks.
class Foo;
  rand int x;
  rand int y;
  rand int z;
  constraint c {
    x inside {[0:1]};
    if (x == 0) {
      y inside {[100:200]};
      z inside {[10:20]};
    } else {
      y inside {[500:600]};
      z == 99;
    }
  }
endclass

module top;
  Foo f;
  int fail;
  initial begin
    f = new; fail = 0;
    repeat (20) begin
      void'(f.randomize());
      if (f.x == 0) begin
        if (f.y < 100 || f.y > 200) fail++;
        if (f.z < 10  || f.z > 20)  fail++;
      end else begin
        if (f.y < 500 || f.y > 600) fail++;
        if (f.z != 99)               fail++;
      end
    end
    if (fail == 0)
      $display("PASS: if-block constraint works");
    else
      $display("FAIL: %0d violations (x=%0d y=%0d z=%0d)", fail, f.x, f.y, f.z);
    $finish;
  end
endmodule
