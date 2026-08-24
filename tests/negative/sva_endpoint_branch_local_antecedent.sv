// NEG-DIAG: an NFA implication local-variable assignment must occur exactly once on a deterministic leaf prefix
// The two antecedent branches can assign different values at different ticks.
// One value register per attempt would let the later branch overwrite the
// earlier endpoint's data, so this remains loudly unsupported until the NFA
// has one local-value carrier per live path.
module sva_endpoint_branch_local_antecedent;
  logic clk, start, left_endpoint, right_endpoint, q;
  logic [7:0] observed;

  property p;
    logic [7:0] saved;
    (start ##1 (left_endpoint, saved = 8'h11)) or
    (start ##2 (right_endpoint, saved = 8'h22))
      |-> q ##1 (observed == saved);
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
