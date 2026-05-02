// sva_sequence_test.sv — verify `sequence ... endsequence` and
//   `property ... endproperty` declarations parse without erroring.
//   The body is consumed via bison's error recovery; no temporal
//   semantics are modelled. This unblocks SVA-rich modules like
//   tlul_assert.sv when they aren't gated behind SYNTHESIS.

module top;
  logic clk = 0, a = 1, b = 1;
  logic [3:0] idx = 0;
  always #5 clk = ~clk;

  // No-arg sequence — parsed and dropped.
  sequence h2d_pre_S;
    a;
  endsequence

  // Parameterised sequence — body uses arbitrary expressions.
  sequence pendingReqPerSrc_S(input bit [3:0] sid);
    1'b1;
  endsequence

  // Property declaration with disable iff — also dropped.
  property req_resp_ok;
    @(posedge clk) disable iff (!a) a |-> b;
  endproperty

  initial begin
    #50 $display("PASS sva_sequence_test compiled and ran");
    $finish;
  end
endmodule
