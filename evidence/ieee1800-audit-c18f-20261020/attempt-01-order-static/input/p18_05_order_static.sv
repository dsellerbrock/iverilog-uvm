class B0; rand bit s; rand bit [31:0] d; constraint c { s -> d == 0; } endclass
class B1; rand bit s; rand bit [31:0] d; constraint c { s -> d == 0; } constraint order { solve s before d; } endclass
class S; rand int x; static constraint c { x == 5; } endclass
class N; rand int x; constraint c { x == 5; } endclass
module p18o;
 int pass=0, fail=0; task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
 B0 b0 = new; B1 b1 = new; S sa = new, sb = new; N na = new, nb = new; int n0 = 0, n1 = 0, r, bad = 0;
 initial begin
  repeat (400) begin r = b0.randomize(); if (r != 1) bad++; if (b0.s) n0++; if (b0.s && b0.d != 0) bad++; end
  repeat (400) begin r = b1.randomize(); if (r != 1) bad++; if (b1.s) n1++; if (b1.s && b1.d != 0) bad++; end
  $display("INFO s=1 unordered %0d/400 ordered %0d/400", n0, n1);
  ck("constraint_holds", bad == 0); ck("unordered_rare", n0 <= 2); ck("ordered_half", n1 >= 150 && n1 <= 250);
  sa.c.constraint_mode(0); ck("static_mode_shared", sb.c.constraint_mode() == 0);
  r = sb.randomize() with { x == 7; }; ck("static_off_all", r == 1 && sb.x == 7);
  sb.c.constraint_mode(1); r = sa.randomize() with { x == 7; }; ck("static_on_all", r == 0);
  na.c.constraint_mode(0); ck("nonstatic_independent", nb.c.constraint_mode() == 1);
  $display("RESULT pass=%0d fail=%0d", pass, fail); end
endmodule
