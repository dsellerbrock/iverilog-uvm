// Companion to sva_undefined_name_inert: the strictness must cover more
// than bare single-component names. A bit select, a part select in a
// comparison, and a struct-member reference on an undefined base were
// all silently inert too, so a fix keyed on `name.size()==1 &&
// index.empty()' would have left three live holes.
module sva_undefined_indexed_inert;
  logic clk = 0, p = 0;
  A1: assert property (@(posedge clk) NoSuchBus[0] |=> p);
  A2: assert property (@(posedge clk) NoSuchBus2[3:0] != 0 |=> p);
  A3: assert property (@(posedge clk) NoSuchStruct.fld |=> p);
endmodule
