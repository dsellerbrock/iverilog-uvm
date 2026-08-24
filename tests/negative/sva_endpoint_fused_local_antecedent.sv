// NEG-DIAG: an NFA implication local-variable assignment followed by a zero-inclusive continuation read requires assignment-before-read scheduling
// NEG-DIAG-COUNT: 1
// A match-item assignment is sequenced before the following ##0 expression
// on the same sampled edge. The current endpoint-obligation engine evaluates
// that expression before committing the per-attempt local, so this legal form
// must remain loud until the ordering is represented exactly.
module sva_endpoint_fused_local_antecedent;
  logic clk, start, endpoint, q;
  logic [7:0] tag, observed;

  property p;
    logic [7:0] saved;
    (start, saved = tag) ##0 (observed == saved) ##[1:2] endpoint
      |-> q;
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
