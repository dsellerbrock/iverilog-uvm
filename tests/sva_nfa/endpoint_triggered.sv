// M9-NFA stage C.3: sequence endpoint methods `seq.triggered' /
// `seq.matched' (IEEE 1800-2017 16.13.6). For a fixed-length named
// sequence the endpoint is lowered to the $past match indicator
// (`a ##1 b' -> `$past(a,1) && b'), a source transform BOTH engines
// lower identically — so this is an ordinary dual-run parity test (not
// nfa_only). Under a single clock `.triggered' and `.matched' coincide.
//
// s1 = a ##1 b. s1 completes at cyc1 (a@0,b@1) with c@1 -> pass; and at
// cyc4 (a@3,b@4) with c@4=0 -> fail. The cover counts both completions.
module endpoint_triggered_t;
  logic clk=0, a=0, b=0, c=0;
  always #5 clk = ~clk;

  sequence s1; a ##1 b; endsequence

  p:   assert property (@(posedge clk) s1.triggered |-> c)
         else $display("EP_FAIL@%0t", $time);
  cnt: cover  property (@(posedge clk) s1.matched);

  initial begin
    @(negedge clk) a=1;              // 0  a
    @(negedge clk) a=0; b=1; c=1;    // 1  b,c -> s1 done, c=1 -> pass
    @(negedge clk) b=0; c=0;         // 2
    @(negedge clk) a=1;              // 3  a
    @(negedge clk) a=0; b=1; c=0;    // 4  b, c=0 -> s1 done, c=0 -> FAIL
    @(negedge clk) b=0;              // 5
    repeat(2) @(negedge clk);
    $display("endpoint_cover=%0d", _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
