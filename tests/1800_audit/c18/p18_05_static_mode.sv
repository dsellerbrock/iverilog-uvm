class S; rand int x; static constraint c { x == 5; } endclass
class N; rand int x; constraint c { x == 5; } endclass
module t;
 S a = new, b = new; N na = new, nb = new; int ra, rb, pass=0, fail=0;
 task automatic ck(input string id, input bit ok); if (ok) pass++; else begin fail++; $display("FAIL %s", id); end endtask
 initial begin
  $display("INIT handles a_null=%0d b_null=%0d modes=%0d,%0d", a == null, b == null, a.c.constraint_mode(), b.c.constraint_mode());
  ra = a.randomize() with { x == 7; };
  $display("INIT constrained randomize rc=%0d x=%0d", ra, a.x);
  ck("static_initial_enforced", ra == 0);
  a.c.constraint_mode(0);
  $display("OFF modes=%0d,%0d", a.c.constraint_mode(), b.c.constraint_mode());
  rb = b.randomize() with { x == 7; };
  $display("OFF randomize rc=%0d x=%0d", rb, b.x);
  ck("static_mode_shared", b.c.constraint_mode() == 0);
  ck("static_off_all", rb == 1 && b.x == 7);
  b.c.constraint_mode(1);
  $display("ON modes=%0d,%0d", a.c.constraint_mode(), b.c.constraint_mode());
  ra = a.randomize() with { x == 7; };
  $display("ON randomize rc=%0d x=%0d", ra, a.x);
  ck("static_on_all", a.c.constraint_mode() == 1 && ra == 0);
  na.c.constraint_mode(0);
  ck("nonstatic_independent", nb.c.constraint_mode() == 1);
  $display("RESULT pass=%0d fail=%0d", pass, fail); if (fail != 0) $fatal(1, "probe failed");
 end
endmodule
