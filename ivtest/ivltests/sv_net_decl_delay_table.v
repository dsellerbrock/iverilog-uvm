`timescale 1ns/1ps

`define DNET(NAME, KIND) module NAME(p); inout p; KIND #5 p; endmodule
`DNET(di_wire, wire)
`DNET(di_wand, wand)
`DNET(di_wor, wor)
`DNET(di_tri0, tri0)
`DNET(di_tri1, tri1)
`DNET(di_uwire, uwire)
`DNET(di_supply0, supply0)
`DNET(di_supply1, supply1)

`define CELL(ETYPE, ENAME, ITAG, IMOD) \
  ETYPE #3 n_``ITAG``_``ENAME; \
  IMOD u_``ITAG``_``ENAME(n_``ITAG``_``ENAME);

`define ROW(ITAG, IMOD) \
  `CELL(wire, wire, ITAG, IMOD) \
  `CELL(wand, wand, ITAG, IMOD) \
  `CELL(wor, wor, ITAG, IMOD) \
  `CELL(tri0, tri0, ITAG, IMOD) \
  `CELL(tri1, tri1, ITAG, IMOD) \
  `CELL(uwire, uwire, ITAG, IMOD) \
  `CELL(supply0, supply0, ITAG, IMOD) \
  `CELL(supply1, supply1, ITAG, IMOD)

module top;
  // Rows are internal types and columns are external types from Table 23-1.
  `ROW(wire, di_wire)
  `ROW(wand, di_wand)
  `ROW(wor, di_wor)
  `ROW(tri0, di_tri0)
  `ROW(tri1, di_tri1)
  `ROW(uwire, di_uwire)
  `ROW(supply0, di_supply0)
  `ROW(supply1, di_supply1)

  initial begin
    #10;
    $display("PASSED");
  end
endmodule
