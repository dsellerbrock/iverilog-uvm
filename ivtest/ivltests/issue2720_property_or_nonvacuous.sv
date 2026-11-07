module issue2720_property_or_nonvacuous;
  bit clk = 0, a = 1, b = 0, c = 0, e = 0;
  always #5 clk = ~clk;

  // The first implication fails nonvacuously; the second passes vacuously.
  o1: assert property (@(posedge clk) (a |-> b) or (c |-> b));
  // A sequence attempt is always nonvacuous, even when it fails.
  o2: assert property (@(posedge clk) e or (c |-> b));

  initial begin
    $setup_issue2720_callbacks;
    repeat (5) @(posedge clk);
    #1 $check_issue2720_callbacks;
    $finish;
  end
endmodule
