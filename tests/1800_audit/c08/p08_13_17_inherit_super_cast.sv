module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  class Packet; integer i = 1; integer value = 3;
    function integer get(); get = i; endfunction
    function integer delay(); delay = value * value; endfunction
    function integer base_only(); return 40; endfunction endclass
  class LinkedPacket extends Packet; integer i = 2; integer value = 5;
    function integer get(); get = -i; endfunction
    function integer delay(); delay = super.delay() + value * super.value; endfunction
    function integer sup_i(); return super.i; endfunction endclass
  class P5; int v; function new(int a); v = a; endfunction endclass
  class E1 extends P5(5); endclass
  class E2 extends P5; function new(); super.new(7); endfunction endclass
  class Ord; static string log = ""; function new(); log = {log, "A"}; endfunction endclass
  class Ord2 extends Ord; function new(); log = {log, "B"}; endfunction endclass
  class Ord3 extends Ord2; function new(); super.new(); log = {log, "C"}; endfunction endclass
  LinkedPacket lp, lp2; Packet p; E1 e1; E2 e2; Ord3 o3; int ok;
  initial begin
    lp = new; p = lp;
    chk("8.13.inherited_method", lp.base_only() == 40);
    chk("8.14.base_view_property", p.i == 1);
    chk("8.14.base_view_nonvirtual_method", p.get() == 1);
    chk("8.14.derived_view", lp.i == 2 && lp.get() == -2);
    chk("8.15.super_member_and_method", lp.delay() == 24);
    chk("8.15.super_property", lp.sup_i() == 1);
    ok = $cast(lp2, p); chk("8.16.cast_down_ok", ok && lp2 == lp);
    p = new; ok = $cast(lp2, p); chk("8.16.cast_down_fail", ok == 0);
    ok = $cast(lp2, null); chk("8.16.cast_null_literal", ok == 1 && lp2 == null);
    e1 = new; chk("8.17.extends_args", e1.v == 5);
    e2 = new; chk("8.17.super_new_args", e2.v == 7);
    o3 = new; chk("8.17.chain_order_implicit_super", Ord::log == "ABC");
    $display("DONE fails=%0d", fails);
  end
endmodule
