module top;
  class X; rand int x; rand bit [15:0] v; constraint c { x < 10; } endclass
  X a, b; int ra, rb;
  initial begin a = new; a.x.rand_mode(0); a.c.constraint_mode(0); b = new a;
    $display("%s rand_mode", b.x.rand_mode() == 0 ? "PASS" : "FAIL");
    $display("%s constraint_mode", b.c.constraint_mode() == 0 ? "PASS" : "FAIL");
    a = new; void'(a.randomize()); b = new a; ra = a.randomize(); rb = b.randomize();
    $display("%s rng_state", (ra && rb && a.v == b.v) ? "PASS" : "FAIL"); end
endmodule
