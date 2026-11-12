// IEEE 1800-2017 18.5.13 / 1800-2023 18.5.12, Figure 18-3.
class leaf; int v; endclass
class guard_test;
  leaf h;
  rand bit r, x;
  bit zero = 0, one = 1;
  constraint c_and { (r && (h.v == 1)) -> x == 1; }
  constraint c_or  { (r || (h.v == 1)) -> x == 1; }
  constraint c_and_rev { ((h.v == 1) && r) -> x == 1; }
  constraint c_or_rev  { if ((h.v == 1) || r) x == 1; }
  constraint c_mask_and { ((r && (h.v == 1)) && zero) -> x == 1; }
  constraint c_mask_or { if ((r || (h.v == 1)) || one) x == 1; }
endclass
module main;
  guard_test t = new;
  initial begin
    t.c_and.constraint_mode(0); t.c_or.constraint_mode(0);
    t.c_and_rev.constraint_mode(0); t.c_or_rev.constraint_mode(0);
    t.c_mask_and.constraint_mode(0); t.c_mask_or.constraint_mode(0);
    t.c_and.constraint_mode(1);
    if (t.randomize()) $fatal(1, "R && E must fail");
    t.c_and.constraint_mode(0); t.c_or.constraint_mode(1);
    if (t.randomize()) $fatal(1, "R || E must fail");
    t.c_or.constraint_mode(0); t.c_and_rev.constraint_mode(1);
    if (t.randomize()) $fatal(1, "E && R must fail");
    t.c_and_rev.constraint_mode(0); t.c_or_rev.constraint_mode(1);
    if (t.randomize()) $fatal(1, "E || R must fail");
    t.c_or_rev.constraint_mode(0); t.c_mask_and.constraint_mode(1);
    if (!t.randomize()) $fatal(1, "false must mask error");
    t.c_mask_and.constraint_mode(0); t.c_mask_or.constraint_mode(1);
    if (!t.randomize() || t.x != 1) $fatal(1, "true must mask error");
    $display("PASSED");
  end
endmodule
