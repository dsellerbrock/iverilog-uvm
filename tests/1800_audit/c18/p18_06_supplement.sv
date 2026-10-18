module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  class Pre; rand bit [7:0] x; int lim; int pre_n; bit [7:0] seen; constraint c { x < lim; }
    function void pre_randomize(); pre_n++; lim = 4; endfunction
    function void post_randomize(); seen = x; endfunction endclass
  class Inf; rand int x; int pre_n; constraint c { x > 5; x < 3; }
    function void pre_randomize(); pre_n++; endfunction endclass
  class B0; int who; function void pre_randomize(); who = 1; endfunction endclass
  class B1 extends B0; rand int y;
    function void pre_randomize(); super.pre_randomize(); who = who + 10; endfunction endclass
  class Leaf; rand bit [15:0] v; int pre_n; function void pre_randomize(); pre_n++; endfunction endclass
  class Mid; rand Leaf l = new; endclass
  class Outer; rand Mid m = new; endclass
  class St; rand static bit [15:0] sv; endclass
  class R; rand bit [31:0] v; endclass
  Pre p; Inf f; B0 b; B1 d; Outer o; St s1, s2; R r1, r2; int ok, chg; bit [15:0] prev;
  initial begin
    p = new; p.lim = 200; ok = 1;
    repeat (20) ok &= p.randomize() && p.x < 4 && p.seen == p.x;
    chk("18.6.2.pre_before_solve_post_after_assign", ok && p.pre_n == 20);
    f = new; void'(f.randomize()); chk("18.6.2.pre_called_on_failure", f.pre_n == 1);
    d = new; b = d; void'(b.randomize()); chk("18.6.2.hooks_dispatch_dynamic_type", d.who == 11);
    o = new; prev = o.m.l.v; chg = 0;
    repeat (8) begin void'(o.randomize()); if (o.m.l.v != prev) chg++; prev = o.m.l.v; end
    chk("18.6.2.nested_members_randomized_and_hooked", chg >= 6 && o.m.l.pre_n == 8);
    s1 = new; s2 = new; chg = 0; prev = St::sv;
    repeat (8) begin void'(s1.randomize()); if (St::sv != prev) chg++; prev = St::sv; end
    chk("18.6.3.static_rand_changes_everywhere", chg >= 6 && s2.sv == s1.sv);
    r1 = new; r2 = new; r1.srandom(42); r2.srandom(42); ok = 1;
    repeat (5) begin void'(r1.randomize()); void'(r2.randomize()); ok &= (r1.v == r2.v); end
    chk("18.6.3.srandom_object_stability", ok);
    $display("DONE fails=%0d", fails);
  end
endmodule
