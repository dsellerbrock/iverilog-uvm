// NEG-DIAG: an NFA implication local-variable assignment followed by a zero-inclusive continuation read requires assignment-before-read scheduling
// NEG-DIAG-COUNT: 1
module sva_endpoint_fused_zero_range_antecedent;
  logic clk, start, endpoint, q;
  logic [7:0] tag, observed;

  property p;
    logic [7:0] saved;
    (start, saved = tag) ##[0:1] (observed == saved)
      ##[1:2] endpoint |-> q;
  endproperty

  ap: assert property (@(posedge clk) p);
endmodule
