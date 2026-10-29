module top;
  logic clk = 0;
  logic start = 0;
  logic a = 0, b = 0, c = 0, d = 0, e = 0;
  int failures = 0;

  always #5 clk = ~clk;

  property and_local_flow;
    bit local_value;
    start |->
      ((a ##1 (b, local_value = 1)) and (c ##1 d))
      ##1 (e && local_value);
  endproperty

  property intersect_local_flow;
    bit local_value;
    start |->
      ((a ##1 (b, local_value = 1)) intersect (c ##1 d))
      ##1 (e && local_value);
  endproperty

  assert property (@(posedge clk) and_local_flow)
    else begin failures++; $display("AND_ASSERT_FAIL %0t", $time); end
  assert property (@(posedge clk) intersect_local_flow)
    else begin failures++; $display("INTERSECT_ASSERT_FAIL %0t", $time); end

  initial begin
    @(negedge clk);
    start = 1;
    a = 1;
    c = 1;
    @(negedge clk);
    start = 0;
    a = 0;
    c = 0;
    b = 1;
    d = 1;
    @(negedge clk);
    b = 0;
    d = 0;
    e = 1;
    @(negedge clk);
    e = 0;
    repeat (2) @(negedge clk);
    if (failures != 0)
      $fatal(1, "local flow through sequence and/intersect failed");
    $display("PASSED");
    $finish(0);
  end
endmodule
