module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  class S; static int shared = 3; static int current = 0;
    static function int next_id(); next_id = ++current; endfunction
    static function int twice(); return next_id() + next_id(); endfunction
    static task t1(output int o); int k; k = k + 1; o = k; endtask
  endclass
  class Demo; integer x;
    function new(integer x); this.x = x; endfunction
    function Demo self(); return this; endfunction
  endclass
  class baseA; integer j = 5; endclass
  class B; integer i = 1; baseA a = new; endclass
  class xtndA extends baseA; rand int x; constraint cst1 { x < 10; } endclass
  class Cnt; static int ctors = 0, inits = 0; int k = bump();
    static function int bump(); inits++; return 5; endfunction
    function new(); ctors++; endfunction
  endclass
  class R; rand bit [15:0] v; endclass
  class L; int val; L next; endclass
  S s0, s1, s2; Demo dm; B b1, b2; xtndA xt, xt2; baseA base2, base3; Cnt c1, c2;
  R r1, r2; L p; int o1, o2, a, b;
  initial begin
    chk("8.9.no_object", S::shared == 3);
    chk("8.9.via_null_handle", s0.shared == 3);
    s1 = new; s2 = new; s1.shared = 9;
    chk("8.9.shared_single_copy", s2.shared == 9 && S::shared == 9);
    a = S::next_id(); b = S::next_id();
    chk("8.10.static_call_no_instance", a == 1 && b == 2);
    chk("8.10.static_calls_static", S::twice() == 7);
    S::t1(o1); S::t1(o2);
    chk("8.10.static_task_automatic_vars", o1 == 1 && o2 == 1);
    dm = new(12);
    chk("8.11.this_disambiguates_arg", dm.x == 12);
    chk("8.11.this_is_handle", dm.self() == dm);
    b1 = new; b2 = new b1; b2.i = 10; b2.a.j = 50;
    chk("8.12.shallow_copies_scalar", b1.i == 1 && b2.i == 10);
    chk("8.12.shallow_shares_nested", b1.a.j == 50 && b1.a == b2.a);
    chk("8.12.copy_is_new_object", b1 != b2);
    xt = new; xt.x = 3; base2 = xt; base3 = new base2;
    chk("8.12.copy_dyn_type", $cast(xt2, base3) && xt2.x == 3 && xt2 != xt);
    c1 = new; c1.k = 9; c2 = new c1;
    chk("8.12.copy_no_ctor_no_init", Cnt::ctors == 1 && Cnt::inits == 1 && c2.k == 9);
    xt.x.rand_mode(0); xt.cst1.constraint_mode(0); xt2 = new xt;
    chk("8.12.copy_rand_mode", xt2.x.rand_mode() == 0);
    chk("8.12.copy_constraint_mode", xt2.cst1.constraint_mode() == 0);
    r1 = new; void'(r1.randomize()); r2 = new r1;
    a = r1.randomize(); b = r2.randomize();
    chk("8.12.copy_rng_state", a && b && r1.v == r2.v);
    p = new; p.next = new; p.next.next = new; p.next.next.val = 77;
    chk("8.12.chained_access", p.next.next.val == 77);
    $display("DONE fails=%0d", fails);
  end
endmodule
