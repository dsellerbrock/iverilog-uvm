// NEG-DIAG: an NFA implication dependent local-variable assignment RHS reads a declared property local before it is assigned on the deterministic prefix
// NEG-DIAG-COUNT: 1
// The property-local `first' is assigned later, so this earlier RHS must not
// resolve to the colliding module signal while its local value is unavailable.
module sva_endpoint_dependent_local_rhs_future_collision;
  logic clk, start, mid, endpoint, q;
  logic [7:0] first = 8'hee;
  logic [7:0] tag;

  property p;
    logic [7:0] first;
    logic [7:0] second;
    (start, second = first + 1) ##1 (mid, first = tag)
      ##[1:2] endpoint |-> q;
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
