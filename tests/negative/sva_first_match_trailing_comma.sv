// NEG-DIAG: syntax error
module sva_first_match_trailing_comma;
  logic clk, a;
  property p;
    @(posedge clk) first_match(a,);
  endproperty
  assert property (p);
endmodule
