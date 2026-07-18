// M5-if regression: continuous assigns whose l-value is a member of an
// interface port (with or without a modport qualifier), and a bare
// module-scope virtual-interface variable declaration.
//
// 1. `assign b.req = expr;` has no static member net to drive -- the
//    member resolves through the class-typed handle at run time.
//    PGAssign now detects the shape BEFORE elaborate_lnet (whose mere
//    call coerced the handle variable into an object net and crashed
//    the vif init) and lowers to the behavioral equivalent: a T0
//    initial apply plus, for non-constant r-values, an always @*
//    re-apply. Previously: "internal error: cannot synthesize
//    expression: <null>".
// 2. `virtual bus_if v;` at module scope parsed as "Invalid module
//    item": the post-K_virtual module state only expected K_class.
module iface_member_assign_test;
  bit ok_const, ok_dyn, ok_vif;
  logic src = 0;

  bus_if bi();
  bus_if bi2();
  drv_const dc(bi.drv);
  drv_dyn   dd(bi2.drv, src);

  virtual bus_if v;            // bare module-scope virtual interface

  initial begin
    v = bi;
    #1;
    ok_const = (bi.req === 1'b1);          // T0 constant assign landed
    if (v.req === 1'b1) ok_vif = 1;        // read through the vif
    src = 1;
    #1;
    ok_dyn = (bi2.req === 1'b1);           // dynamic assign tracked src
    if (ok_const && ok_dyn && ok_vif)
      $display("PASS: interface member assigns and bare virtual decl");
    else
      $display("FAIL: const=%b dyn=%b vif=%b", ok_const, ok_dyn, ok_vif);
    $finish;
  end
endmodule
interface bus_if;
  logic req, ack;
  modport drv (output req, input ack);
endinterface
module drv_const(bus_if.drv b);
  assign b.req = 1'b1;
endmodule
module drv_dyn(bus_if.drv b, input logic s);
  assign b.req = s;
endmodule
