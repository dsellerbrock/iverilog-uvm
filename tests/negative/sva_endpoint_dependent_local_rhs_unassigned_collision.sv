// NEG-DIAG: an NFA implication dependent local-variable assignment RHS reads a declared property local before it is assigned on the deterministic prefix
// NEG-DIAG-COUNT: 1
// The declaration-local `first' shadows this module signal. It must not be
// sampled globally merely because it never appears as an assignment target.
module sva_endpoint_dependent_local_rhs_unassigned_collision;
  logic clk, start, endpoint, q;
  logic [7:0] first = 8'hee;

  property p;
    logic [7:0] first;
    logic [7:0] second;
    (start, second = first + 1) ##[1:2] endpoint |-> q;
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
