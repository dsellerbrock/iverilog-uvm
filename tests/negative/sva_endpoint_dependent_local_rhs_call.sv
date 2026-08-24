// NEG-DIAG: an NFA implication dependent local-variable assignment RHS must read only an earlier deterministic-prefix local through a structurally supported expression
// NEG-DIAG-COUNT: 1
// A call that consumes per-attempt state needs a purity/lifetime model that the
// structural RHS lowering does not yet provide. Reject it once rather than
// resolving `first' against a module-level collision or sampling it globally.
module sva_endpoint_dependent_local_rhs_call;
  logic clk, start, mid, endpoint, q;
  logic [7:0] tag;
  logic [7:0] first = 8'hee;

  function automatic logic [7:0] bump(input logic [7:0] value);
    return value + 1;
  endfunction

  property p;
    logic [7:0] first;
    logic [7:0] second;
    (start, first = tag) ##1 (mid, second = bump(first))
      ##[1:2] endpoint |-> q;
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
