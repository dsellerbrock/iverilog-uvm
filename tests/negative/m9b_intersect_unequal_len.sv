// NEG-LEGACY-ONLY
// The default automaton engine accepts this legal unequal-length form and
// lowers it as an empty intersection. The legacy linear engine still rejects
// it explicitly.
module top; logic clk=0,a,b,c;
  assert property (@(posedge clk) (a ##1 b) intersect (c));
endmodule
