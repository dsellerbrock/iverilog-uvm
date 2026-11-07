// NEG-DIAG: as an implication consequent is not supported yet
// NEG-DIAG-COUNT: 1
// IEEE 1800-2023 16.12.14 permits an abort over a temporal property inside
// an implication consequent (`... |-> reject_on(stop) put[->2]'). The
// per-attempt abort lowering does not host one inside a consequence
// obligation yet, so it must be refused loudly rather than lowered as a
// stand-alone operand.
module sva_abort_consequent_unhosted;
  bit clk = 0, go, get, put, stop;
  always #5 clk = ~clk;
  bad: assert property (@(posedge clk) go ##1 get[*2] |-> reject_on(stop) put[->2]);
endmodule
