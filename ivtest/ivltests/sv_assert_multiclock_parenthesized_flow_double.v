module main;
  logic clk0=0, clk1=0, w=0, x=0, y=0, z=0;
  integer failures=0, hits=0;

  always #5 clk0=~clk0;
  always #7 clk1=~clk1;

  p: assert property (
      @(posedge clk0) w ##1 ((x ##1 @(posedge clk1) y)) |=> z)
      ;
    else begin
      if ($time != 85) $fatal(1, "Unexpected assertion failure at %0t", $time);
      failures++;
    end

  c: cover property (
      @(posedge clk0) w ##1 ((x ##1 @(posedge clk1) y)) |=> z) begin
    if ($time != 25) $fatal(1, "Unexpected cover hit at %0t", $time);
    hits++;
  end

  initial begin
    #1 $assertvacuousoff(0, c);

    // w at 5, x at 15, y at 21, and a true z at 25.
    w=1;
    #6 begin w=0; x=1; end
    #10 begin x=0; y=1; end
    #7 begin y=0; z=1; end
    #2 z=0;

    // w at 65, x at 75, y at 77, and a false z at 85.
    #35 w=1;
    #6 begin w=0; x=1; end
    #9 begin x=0; y=1; end
    #2 y=0;

    #22;
    if (failures != 1 || hits != 1)
      $fatal(1, "Expected one failure and one hit. Got %0d and %0d", failures, hits);
    $display("PASSED");
    $finish(0);
  end
endmodule
