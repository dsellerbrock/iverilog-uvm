// NEG-DIAG: an NFA implication local-variable assignment followed by a zero-inclusive continuation read requires assignment-before-read scheduling
// NEG-DIAG-COUNT: 1
// Consequence records have independent locals, but their fused-edge guard is
// still evaluated before the match-item capture. Keep the legal shape loud
// until the capture precedes every same-edge continuation read.
module sva_endpoint_fused_local_consequence;
  logic clk, start, endpoint, q;
  logic [7:0] tag, observed;

  property p;
    logic [7:0] saved;
    start ##[1:2] endpoint
      |-> (q, saved = tag) ##0 (observed == saved);
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
