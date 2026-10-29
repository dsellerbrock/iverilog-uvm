module sv_assert_first_match_duplicate_assignment_fail;
  logic clk = 0, a = 0, b = 0, e = 0;
  int data = 1;
  always #5 clk = ~clk;

  property p;
    int x;
    @(posedge clk) a |-> (first_match(b, x = data, x = x + 1) ##1 e);
  endproperty
  assert property (p);
endmodule
