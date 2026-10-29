module sv_assert_first_match_assignment_ambiguous_fail;
  bit clk=0, a=0, b=0, c=0;
  int d=0;
  always #5 clk=~clk;

  property p;
    int x;
    @(posedge clk) first_match(a ##[1:2] (b, x=d) ##[0:1] c);
  endproperty
  cover property (p);
endmodule
