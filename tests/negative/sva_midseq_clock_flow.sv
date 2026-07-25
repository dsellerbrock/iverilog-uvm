// M9-7: mid-sequence clock flow (IEEE 1800-2017 16.13.1) -- a clocking
// event INSIDE a sequence, rather than at the implication. The cross-clock
// request/ack handoff is built for the boundary at a non-overlapping
// implication and does not generalise to an arbitrary point in a chain, so
// this is unsupported. It used to report a bare "syntax error / Malformed
// statement", which is loud but tells the user nothing; the grammar now
// recognises the shape purely so the diagnostic can name it and point at
// the form that does work.
module top;
  reg c1=0, c2=0, a=0, b=0;
  p: assert property (@(posedge c1) a ##1 @(posedge c2) b);
endmodule
