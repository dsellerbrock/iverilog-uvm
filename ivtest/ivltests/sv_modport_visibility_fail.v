// IEEE 1800-2017 25.5: only the members a modport lists (as directional
// ports or via import/export) are accessible through that modport. A write
// to any other interface member through the modport used to compile
// silently; it must be a clean elaboration error.

module sv_modport_visibility_fail;

  bus_if b();
  driver d(b.master);

endmodule

interface bus_if;
  logic req, gnt, hidden;
  modport master (output req, input gnt);
endinterface

module driver(bus_if.master m);
  initial begin
    m.req = 1;      // legal: listed output
    m.hidden = 1;   // ILLEGAL: not listed in modport master
  end
endmodule
