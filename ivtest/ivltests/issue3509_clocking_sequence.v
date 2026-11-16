module issue3509_clocking_sequence;
  reg clk = 0, c = 1, b = 1;
  integer passes = 0, failures = 0;
  always #5 clk = ~clk;

  // The block-local declaration must shadow this module sequence.
  sequence s_c; !c ##1 !c; endsequence
  clocking cb @(posedge clk);
    sequence s_c; c ##1 c; endsequence
    sequence s_only; c ##1 c; endsequence
    property p_seq; s_c |-> b; endproperty
    property p_other; s_only |-> b; endproperty
  endclocking

  assert property (cb.p_seq) passes = passes + 1;
    else failures = failures + 1;
  assert property (cb.p_seq) passes = passes + 1;
    else failures = failures + 1;

  assert property (cb.p_other) else failures = failures + 1;

  initial begin
    // First match succeeds at 15, the next fails at 25.
    #20 b = 0;
    #10 c = 0;
    #20;
    if (passes !== 8 || failures !== 3) begin
      $display("FAIL passes=%0d failures=%0d", passes, failures);
      $finish(0);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
