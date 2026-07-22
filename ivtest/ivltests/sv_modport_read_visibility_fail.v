// IEEE 1800-2017 25.5: only the members a modport lists (as directional
// ports or via import/export) are accessible through that modport. This is
// the READ-side counterpart to sv_modport_visibility_fail: reading an
// interface member the modport does not list used to compile silently (and
// later ICE in synthesis). It must be a clean elaboration error. Reading a
// LISTED member (input or output) stays legal and is covered by positive
// tests.

module sv_modport_read_visibility_fail;

  bus_if b();
  reader r(b.master);

endmodule

interface bus_if;
  logic req, gnt, hidden;
  modport master (output req, input gnt);
endinterface

module reader(bus_if.master m);
  logic x;
  initial begin
    x = m.gnt;      // legal: listed input
    x = m.hidden;   // ILLEGAL: not listed in modport master
    $display("x=%b", x);
  end
endmodule
