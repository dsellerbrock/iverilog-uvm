// `expect' (IEEE 1800-2017 16.17) with a fixed ##N boolean chain:
// lowers to procedural clock-waits in BOTH engines (dual-run).
// NFA-EXPECT-FALLBACK: no standing checker is synthesized -- the
// expect unrolls procedurally, so no automaton slot registers appear.
module expect_fixed_chain;
  bit clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;
  initial begin
    a = 1;
    fork begin #22 b = 1; end join_none
    expect (@(posedge clk) a ##2 b) $display("T1 pass");
    else $display("T1 fail");
    // failing chain: b low again, window fixed
    b = 0;
    expect (@(posedge clk) a ##1 b) $display("T2 pass");
    else $display("T2 fail");
    $finish(0);
  end
endmodule
