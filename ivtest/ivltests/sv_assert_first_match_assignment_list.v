// IEEE 1800-2017/2023 16.9.8 and 16.10: match-item assignments execute in
// source order at the earliest first_match endpoint.
module sv_assert_first_match_assignment_list;
  logic clk = 0, a = 0, b = 0;
  int data = 0;
  int failures = 0;
  always #5 clk = ~clk;

  sequence s;
    a ##[1:2] b;
  endsequence

  property p;
    int x, y;
    @(posedge clk) a |-> (first_match(s, x = data, y = x + 1) ##1 y == 2);
  endproperty
  assert property (p) else failures++;

  property p_bare_local_rhs;
    int x, y;
    @(posedge clk) a |-> (first_match(s, y = data + 1, x = y) ##1 x == 2);
  endproperty
  assert property (p_bare_local_rhs) else failures++;

  initial begin
    @(negedge clk); a = 1;
    @(negedge clk); a = 0; b = 1; data = 1;
    @(negedge clk); data = 7;
    @(negedge clk); b = 0;
    repeat (2) @(negedge clk);

    if (failures != 0)
      $fatal(1, "first_match assignment-list failures=%0d", failures);
    $display("PASSED: ordered assignments use the earliest first_match endpoint");
    $finish(0);
  end
endmodule
