module sv_assert_first_match_local_flow_fail;
  bit clk, a, b;

  property one_or_write;
    int x;
    @(posedge clk) first_match((a, x = 1) or b) |-> (x == 1);
  endproperty

  property sibling_read;
    int x;
    @(posedge clk) first_match((a, x = 1) or (b ##1 (x == 1))) |-> 1'b1;
  endproperty

  property blocked_and_write;
    int x = 0;
    @(posedge clk) first_match((a, x = 1) and (b, x = 2)) |=> (x == 1);
  endproperty

  property nested_block;
    int x = 0;
    @(posedge clk)
      first_match((((a, x = 1) and (b, x = 2)) or a) and b) |-> (x == 1);
  endproperty
endmodule
