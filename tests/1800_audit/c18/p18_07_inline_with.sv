module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  class Sub; rand bit [7:0] v; endclass
  class C1; rand bit [7:0] x, y, z; rand Sub sub = new; constraint c { z == x + y; } endclass
  class CA; rand bit [7:0] x; endclass
  class CB; rand bit [7:0] x; bit [7:0] y = 50; endclass
  class C2; integer x = 100; integer y = 5;
    function int doit(CA f, integer x, integer z); return f.randomize() with { x < y + z; }; endfunction
  endclass
  function automatic int fr(CB o, bit [7:0] y); return o.randomize() with (x) { x < y; }; endfunction
  function automatic int frl(CB o, bit [7:0] y); return o.randomize() with (x) { x < local::y; }; endfunction
  function automatic int fl(CA o, bit [7:0] x); return o.randomize() with { x < local::x; }; endfunction
  C1 c1; CA a; CB b; C2 c2; int ok;
  initial begin
    c1 = new; a = new; b = new; c2 = new;
    ok = 1; repeat (20) ok &= c1.randomize() with { x < y; } && c1.x < c1.y && c1.z == 8'(c1.x + c1.y);
    chk("18.7.inline_plus_class_constraints", ok);
    ok = 1; repeat (20) ok &= c2.doit(a, 200, 2) && a.x < 7;
    chk("18.7.unrestricted_resolution_obj_then_local", ok);
    ok = 1; repeat (20) ok &= fr(b, 3) && b.x < 3;
    chk("18.7.restricted_idlist_other_names_local", ok);
    ok = 1; repeat (20) ok &= frl(b, 3) && b.x < 3;
    chk("18.7.restricted_with_local_qualifier", ok);
    ok = 1; repeat (20) ok &= fl(a, 4) && a.x < 4;
    chk("18.7.1.local_qualifier_binds_caller", ok);
    chk("18.7.this_binds_object_class", (a.randomize() with { this.x == 9; }) && a.x == 9);
    chk("18.7.dotted_names_downward", (c1.randomize() with { sub.v == 7; }) && c1.sub.v == 7);
    ok = 0; if (c1.randomize() with { x == 1; y == 2; }) ok = (c1.z == 3);
    chk("18.7.usable_in_expression", ok);
    chk("18.7.infeasible_returns_0", (c1.randomize() with { x > 5; x < 3; }) == 0);
    ok = 1; repeat (20) ok &= c1.randomize() with { x inside {[10:12]}; (x == 10) -> y == 0; }
                         && c1.x inside {[10:12]} && (c1.x != 10 || c1.y == 0);
    chk("18.7.inline_constraint_forms", ok);
    $display("DONE fails=%0d", fails);
  end
endmodule
