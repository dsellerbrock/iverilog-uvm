// NEG-DIAG: an NFA implication dependent local-variable assignment RHS reads a declared property local before it is assigned on the deterministic prefix
// NEG-DIAG-COUNT: 1
// `first' is a property local even though it has no assignment destination.
// Reject its read during property lowering, before ordinary name resolution.
module sva_endpoint_dependent_local_rhs_unassigned;
  logic clk, start, endpoint, q;

  property p;
    logic [7:0] first;
    logic [7:0] second;
    (start, second = first + 1) ##[1:2] endpoint |-> q;
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
