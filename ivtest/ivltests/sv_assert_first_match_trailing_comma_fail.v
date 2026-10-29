module sv_assert_first_match_trailing_comma_fail;
  logic clk, a;
  property p;
    @(posedge clk) first_match(a,);
  endproperty
  assert property (p);
endmodule
