// Change-sensitivity on an interface-member read now fires correctly. A
// continuous assign or an explicit event whose sensitivity source is an
// interface-member read (`assign p.b = p.a;`, `always @(p.a) ...`) used to
// never re-trigger: interfaces are modeled as class objects, so the member
// read lowered to a property access whose value-change event was built on
// the object HANDLE (which never changes after binding) instead of the
// underlying interface signal. The port handle IS the virtual-interface
// object, so the fix encodes a DIRECT virtual-interface edge probe
// (%wait/vif/anyedge on the member) for `p.sig`, and the vif-member
// continuous-assign lowering sensitizes on `@(<rhs>)` rather than `@*`.
// A real-net r-value (`assign inf.req = rnd[0];`, ivltests/sv_interface.v)
// is unaffected. (IEEE 1800-2017 10.4 / 9.4.2 / 25.x.)
interface simple_if;
  logic a;
  logic b;
  logic c;
endinterface

// Continuous assign through an interface port member.
module ca_driver(simple_if p);
  assign p.b = p.a;
endmodule

// Explicit anyedge event on an interface port member.
module ev_driver(simple_if p);
  always @(p.a) p.c = p.a;
endmodule

// Explicit posedge event on an interface port member (edge-qualified: a
// vif posedge/negedge probe must NOT wire an edge functor onto the object
// handle net, or its recv_object aborts).
interface clk_if;
  logic clk;
  int   cnt;
endinterface
module cnt_driver(clk_if p);
  always @(posedge p.clk) p.cnt <= p.cnt + 1;
endmodule

module sv_interface_member_sensitivity;
  simple_if intf();
  ca_driver ca(intf);
  ev_driver ev(intf);
  clk_if    cif();
  cnt_driver cd(cif);
  int errors = 0;

  initial begin
    intf.a = 0; #1;
    intf.a = 1; #1;
    if (intf.b !== 1'b1) begin $display("FAIL: continuous assign b=%b (expect 1)", intf.b); errors++; end
    if (intf.c !== 1'b1) begin $display("FAIL: event c=%b (expect 1)", intf.c); errors++; end
    intf.a = 0; #1;
    if (intf.b !== 1'b0) begin $display("FAIL: continuous assign b=%b (expect 0)", intf.b); errors++; end
    if (intf.c !== 1'b0) begin $display("FAIL: event c=%b (expect 0)", intf.c); errors++; end

    // posedge on an interface member drives a counter three times.
    cif.cnt = 0; cif.clk = 0;
    repeat (3) begin #1 cif.clk = 1; #1 cif.clk = 0; end
    #1 if (cif.cnt !== 3) begin $display("FAIL: posedge cnt=%0d (expect 3)", cif.cnt); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
