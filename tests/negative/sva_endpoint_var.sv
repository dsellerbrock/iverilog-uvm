// M9-NFA stage C.3: `seq.triggered'/`seq.matched' is lowered only for a
// fixed-length sequence (to the $past match indicator). A variable-length
// sequence body needs the automaton endpoint signal, which is not yet
// synthesized as a standalone boolean, so it must be rejected with a loud
// sorry rather than silently mislowered.
module sva_endpoint_var;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk=~clk;
  sequence sv; a ##[1:3] b; endsequence
  p: assert property (@(posedge clk) sv.triggered |-> c);
  initial begin repeat(3) @(negedge clk); $finish(0); end
endmodule
