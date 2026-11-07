// IEEE 1800-2017/2023 16.13.6: `seq.triggered'/`seq.matched' is lowered for a
// bounded sequence as the OR of its match shapes. An unbounded body
// (##[m:$], [*m:$]) has no finite set of shapes and needs the automaton
// endpoint signal, which is not synthesized as a standalone boolean, so it
// must be rejected with a loud sorry rather than silently mislowered.
module sva_endpoint_var;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk=~clk;
  sequence sv; a ##[1:$] b; endsequence
  p: assert property (@(posedge clk) sv.triggered |-> c);
  initial begin repeat(3) @(negedge clk); $finish(0); end
endmodule
