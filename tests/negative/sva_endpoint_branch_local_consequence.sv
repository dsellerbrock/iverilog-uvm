// NEG-DIAG: an NFA implication local-variable assignment must occur exactly once on a deterministic leaf prefix
// A consequence tree shares one obligation bitset. Branch-local writes need
// per-live-path local state even though each antecedent endpoint already owns
// an independent obligation record, so reject rather than merge the values.
module sva_endpoint_branch_local_consequence;
  logic clk, start, endpoint, q, r;
  logic [7:0] observed;

  property p;
    logic [7:0] saved;
    start ##[1:2] endpoint |->
      ((q, saved = 8'h11) ##1 (observed == saved)) or
      ((r, saved = 8'h22) ##1 (observed == saved));
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
