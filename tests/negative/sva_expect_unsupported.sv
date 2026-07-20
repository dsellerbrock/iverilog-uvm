// M9-frontier (Phase 3): `expect' currently lowers only a fixed-length
// boolean sequence (16.17). A variable-length / implication / combinator
// expect needs the standing checker plus a process-resume hook (a later
// increment); until then it must be a loud sorry, not silently dropped.
module sva_expect_unsupported;
  logic clk=0, a=0, b=0;
  always #5 clk=~clk;
  initial expect (@(posedge clk) a ##[1:3] b) $display("P"); else $display("Q");
endmodule
