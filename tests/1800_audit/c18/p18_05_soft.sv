class Packet; rand bit mode; rand int length;
 constraint deflt { soft length inside {32,1024}; soft mode -> length == 1024; } endclass
class B1; rand int x; constraint a { soft x > 10; soft x < 100; } endclass
class D1 extends B1; constraint b { soft x inside {[5:9]}; } endclass
class A; rand int x; constraint A1 { soft x == 3; } constraint A2 { disable soft x; } constraint A3 { soft x inside {1,2}; } endclass
class S; rand int x; constraint c1 { soft x == 5; } constraint c2 { soft x == 7; } endclass
class H; rand int x; constraint c { x inside {[1:3]}; soft x == 10; } endclass
module p18s;
 int pass=0, fail=0; task automatic ck(input string id, input bit c); if (c) pass++; else begin fail++; $display("FAIL %s", id); end endtask
 Packet p = new; D1 d1 = new; A a = new; S s = new; H h = new; int r;
 initial begin
  r = p.randomize() with { length == 1512; }; ck("soft_dropped", r==1 && p.length==1512 && p.mode==0);
  r = p.randomize() with { length == 1512; mode == 1; }; ck("soft_impl_dropped", r==1 && p.length==1512 && p.mode==1);
  r = p.randomize(); ck("defaults", r==1 && (p.length==32 || p.length==1024) && (p.mode==0 || p.length==1024));
  r = d1.randomize(); ck("derived_wins", r==1 && d1.x>=5 && d1.x<=9);
  r = a.randomize(); ck("disable_soft", r==1 && (a.x==1 || a.x==2));
  r = s.randomize(); ck("later_wins", r==1 && s.x==7);
  r = h.randomize(); ck("hard_beats_soft", r==1 && h.x>=1 && h.x<=3);
  r = s.randomize() with { x == 9; }; ck("inline_hard", r==1 && s.x==9);
  r = s.randomize() with { soft x == 4; }; ck("inline_soft_wins", r==1 && s.x==4);
  $display("RESULT pass=%0d fail=%0d", pass, fail); end
endmodule
